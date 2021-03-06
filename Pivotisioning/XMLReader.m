//
//  XMLReader.m
//  Pivotisioning
//
//  Created by Dev Floater 114 on 2014-12-18.
//  Copyright (c) 2014 Pivotal Labs. All rights reserved.
//

#import "XMLReader.h"

NSString *const kXMLReaderTextNodeKey = @"text";

@interface XMLReader (Internal)

- (NSDictionary *)objectWithData:(NSData *)data;

@end

@interface XMLReader () <NSXMLParserDelegate>

@property (strong) NSMutableArray *dictionaryStack;
@property (strong) NSMutableString *textInProgress;
@property (strong) NSError *errorPointer;

@end

@implementation XMLReader

#pragma mark -
#pragma mark Public methods

+ (NSDictionary *)dictionaryForXMLData:(NSData *)data {
    XMLReader *reader = [XMLReader new];
    NSDictionary *rootDictionary = [reader objectWithData:data];
    return rootDictionary;
}

+ (NSDictionary *)dictionaryForXMLString:(NSString *)string {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [XMLReader dictionaryForXMLData:data];
}

#pragma mark -
#pragma mark Parsing

- (NSDictionary *)objectWithData:(NSData *)data {
    // Clear out any old data
    self.dictionaryStack = nil;
    self.textInProgress = nil;
    
    self.dictionaryStack = [NSMutableArray new];
    self.textInProgress = [NSMutableString new];
    
    // Initialize the stack with a fresh dictionary
    [self.dictionaryStack addObject:[NSMutableDictionary dictionary]];
    
    // Parse the XML
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    BOOL success = [parser parse];
    
    // Return the stack’s root dictionary on success
    if (success) {
        return self.dictionaryStack.firstObject;
    }
    
    return nil;
}

#pragma mark -
#pragma mark NSXMLParserDelegate methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    // Get the dictionary for the current level in the stack
    NSLog(@"didStartElement %@ %@ %@ %@",elementName, namespaceURI, qName, attributeDict);
    NSMutableDictionary *parentDict = [self.dictionaryStack lastObject];
    
    // Create the child dictionary for the new element, and initilaize it with the attributes
    NSMutableDictionary *childDict = [NSMutableDictionary dictionary];
    [childDict addEntriesFromDictionary:attributeDict];
    
    // If there’s already an item for this key, it means we need to create an array
    id existingValue = [parentDict objectForKey:elementName];
    if (existingValue)
    {
        NSMutableArray *array = nil;
        if ([existingValue isKindOfClass:[NSMutableArray class]])
        {
            // The array exists, so use it
            array = (NSMutableArray *) existingValue;
        }
        else
        {
            // Create an array if it doesn’t exist
            array = [NSMutableArray array];
            [array addObject:existingValue];
            
            // Replace the child dictionary with an array of children dictionaries
            [parentDict setObject:array forKey:elementName];
        }
        
        // Add the new child dictionary to the array
        [array addObject:childDict];
    }
    else
    {
        // No existing value, so update the dictionary
        [parentDict setObject:childDict forKey:elementName];
    }
    
    // Update the stack
    [self.dictionaryStack addObject:childDict];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    // Update the parent dict with text info
    NSLog(@"didEndElement %@ %@ %@",elementName, namespaceURI, qName);
    NSMutableDictionary *dictInProgress = [self.dictionaryStack lastObject];
    
    // Set the text property
    if ([self.textInProgress length] > 0)
    {
        // Get rid of leading + trailing whitespace
        [dictInProgress setObject:self.textInProgress forKey:kXMLReaderTextNodeKey];
        
        // Reset the text
        self.textInProgress = [[NSMutableString alloc] init];
    }
    
    // Pop the current dict
    [self.dictionaryStack removeLastObject];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    // Build the text value
    NSLog(@"foundCharacters %@",string);
        [self.textInProgress appendString:[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    // Set the error pointer to the parser’s error object
    self.errorPointer = parseError;
}

@end
