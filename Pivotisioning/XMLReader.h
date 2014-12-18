//
//  XMLReader.h
//  Pivotisioning
//
//  Created by Dev Floater 114 on 2014-12-18.
//  Copyright (c) 2014 Pivotal Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XMLReader : NSObject

+ (NSDictionary *)dictionaryForXMLData:(NSData *)data;
+ (NSDictionary *)dictionaryForXMLString:(NSString *)string;


@end
