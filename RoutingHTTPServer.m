#import "RoutingHTTPServer.h"
#import "RoutingConnection.h"
#import "Route.h"
#import "RegexKitLite.h"

@interface RoutingHTTPServer ()

- (Route *)routeWithPath:(NSString *)path;
- (void)addRoute:(Route *)route forMethod:(NSString *)method;

@end

@implementation RoutingHTTPServer

@synthesize defaultHeaders;

- (id)init {
	if (self = [super init]) {
		connectionClass = [RoutingConnection self];
		routes = [[NSMutableDictionary alloc] init];
		defaultHeaders = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc {
	[routes release];
	[defaultHeaders release];
	[super dealloc];
}

- (void)setDefaultHeaders:(NSDictionary *)headers {
	NSMutableDictionary *newHeaders;
	if (headers) {
		newHeaders = [headers mutableCopy];
	} else {
		newHeaders = [[NSMutableDictionary alloc] init];
	}

	if (defaultHeaders) {
		[defaultHeaders release];
	}
	defaultHeaders = newHeaders;
}

- (void)setDefaultHeader:(NSString *)field value:(NSString *)value {
	[defaultHeaders setObject:value forKey:field];
}

- (void)get:(NSString *)path withBlock:(RequestHandler)block {
	[self handleMethod:@"GET" withPath:path block:block];
}

- (void)post:(NSString *)path withBlock:(RequestHandler)block {
	[self handleMethod:@"POST" withPath:path block:block];
}

- (void)handleGet:(NSString *)path withBlock:(RequestHandler)block {
	[self handleMethod:@"GET" withPath:path block:block];
}

- (void)handlePost:(NSString *)path withBlock:(RequestHandler)block {
	[self handleMethod:@"POST" withPath:path block:block];
}

- (void)handlePut:(NSString *)path withBlock:(RequestHandler)block {
	[self handleMethod:@"PUT" withPath:path block:block];
}

- (void)handleDelete:(NSString *)path withBlock:(RequestHandler)block {
	[self handleMethod:@"DELETE" withPath:path block:block];
}

- (void)handleSubscribe:(NSString *)path withBlock:(RequestHandler)block {
	[self handleMethod:@"SUBSCRIBE" withPath:path block:block];
}

- (void)handleUnsubscribe:(NSString *)path withBlock:(RequestHandler)block {
	[self handleMethod:@"UNSUBSCRIBE" withPath:path block:block];
}

- (void)handleMethod:(NSString *)method withPath:(NSString *)path block:(RequestHandler)block {
	Route *route = [self routeWithPath:path];
	route.handler = block;

	[self addRoute:route forMethod:method];
}

- (void)handleMethod:(NSString *)method withPath:(NSString *)path target:(id)target selector:(SEL)selector {
	Route *route = [self routeWithPath:path];
	route.target = target;
	route.selector = selector;

	[self addRoute:route forMethod:method];
}

- (void)addRoute:(Route *)route forMethod:(NSString *)method {
	NSMutableArray *methodRoutes = [routes objectForKey:method];
	if (methodRoutes == nil) {
		methodRoutes = [NSMutableArray array];
		[routes setObject:methodRoutes forKey:method];
	}

	[methodRoutes addObject:route];
}

- (Route *)routeWithPath:(NSString *)path {
	Route *route = [[[Route alloc] init] autorelease];
	NSMutableArray *keys = [NSMutableArray array];

	// Escape regex characters
	path = [path stringByReplacingOccurrencesOfRegex:@"[.+()]" usingBlock:
			^NSString *(NSInteger captureCount, NSString *const capturedStrings[captureCount], const NSRange capturedRanges[captureCount], volatile BOOL *const stop) {
				return [NSString stringWithFormat:@"\\%@", capturedStrings[0]];
			}];

	// Parse any :parameters in the path
	path = [path stringByReplacingOccurrencesOfRegex:@":(\\w+)" usingBlock:
			^NSString *(NSInteger captureCount, NSString *const capturedStrings[captureCount], const NSRange capturedRanges[captureCount], volatile BOOL *const stop) {
				[keys addObject:capturedStrings[1]];
				return @"([^/?#]+)";
			}];

	path = [NSString stringWithFormat:@"^%@$", path];

	route.path = path;
	if ([keys count] > 0) {
		route.keys = keys;
	}

	return route;
}

- (BOOL)supportsMethod:(NSString *)method {
	return ([routes objectForKey:method] != nil);
}

- (RouteResponse *)routeMethod:(NSString *)method withPath:(NSString *)path parameters:(NSDictionary *)params request:(HTTPMessage *)httpMessage connection:(HTTPConnection *)connection {
	NSMutableArray *methodRoutes = [routes objectForKey:method];
	if (methodRoutes == nil)
		return nil;

	for (Route *route in methodRoutes) {
		// The first element in the captures array is all of the text matched by regex.
		// If there is nothing in the array the regex did not match.
		NSArray *captures = [path captureComponentsMatchedByRegex:route.path];
		if ([captures count] > 0) {
			if (route.keys) {
				// Add the route's parameters to the parameter dictionary, accounting for
				// the first element containing the matched text.
				if ([captures count] == [route.keys count] + 1) {
					NSMutableDictionary *newParams = [[params mutableCopy] autorelease];
					NSUInteger index = 1;
					for (NSString *key in route.keys) {
						[newParams setObject:[captures objectAtIndex:index] forKey:key];
						index++;
					}
					params = newParams;
				}
			}

			RouteRequest *request = [[[RouteRequest alloc] initWithHTTPMessage:httpMessage parameters:params] autorelease];
			RouteResponse *response = [[[RouteResponse alloc] initWithConnection:connection] autorelease];
			if (route.handler) {
				route.handler(request, response);
			} else {
				[route.target performSelector:route.selector withObject:request withObject:response];
			}
			return response;
		}
	}

	return nil;
}

@end