//
//  AppDelegate.m
//  Pivotisioning
//
//  Created by Ivan Rodriguez on 2014-12-17.
//  Copyright (c) 2014 Pivotal Labs. All rights reserved.
//

#import "AppDelegate.h"

static NSString * const kProvisioningProfileListPath = @"~/Library/MobileDevice/Provisioning Profiles";
static NSString * const kArchivesPath = @"~/Library/Developer/Xcode/Archives";

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *archiveLabel;
@property (weak) IBOutlet NSButton *sameAsArchiveButton;
@property (weak) IBOutlet NSPathControl *destinationPathControl;
@property (weak) IBOutlet NSTextField *projectNameTextField;
@property (weak) IBOutlet NSTextField *logLabel;
@property (weak) IBOutlet NSProgressIndicator *spinner;
@property (weak) IBOutlet NSPopUpButton *provisioningPopUpButton;

@property (strong) NSURL *archiveFilePath;
@property (strong) NSURL *archiveDirectoryPath;

@property (strong) NSString *provisioningProfileName;

@property (assign) NSInteger provisioningProfileIndex;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [self initialSetup];
    [self loadProvisioningProfiles];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark - IBActions

- (IBAction)selectArchiveClicked:(NSButtonCell *)sender {
    __weak typeof(self) weakSelf = self;
    [self selectArchiveFileSuccess:^(NSURL *archiveURL) {
        if (archiveURL) {
            weakSelf.archiveFilePath = archiveURL;
            NSString *stringURL = [[weakSelf archiveStringPath] stringByDeletingLastPathComponent];
            weakSelf.archiveDirectoryPath = [NSURL URLWithString:stringURL];
            weakSelf.archiveLabel.stringValue = [weakSelf.archiveFilePath lastPathComponent];
            if (weakSelf.sameAsArchiveButton.state == NSOnState) {
                [weakSelf setDestinationPathFromURL:weakSelf.archiveFilePath];
            }
        }
    }];
}

- (IBAction)archiveDirectoryButtonClicked:(NSButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self selectArchiveDirectorySuccess:^(NSURL *selectedURL) {
        if (selectedURL) {
            weakSelf.archiveDirectoryPath  = selectedURL;
            [weakSelf.sameAsArchiveButton setState:NSOffState];
            [weakSelf setDestinationPathFromURL:weakSelf.archiveDirectoryPath];
        }
    }];
}

- (IBAction)createButtonClicked:(id)sender {
    if ([self inputsAreValid]) {
        [self createBuild];
    } else {
        [self displayCorrectError];
    }
}

- (IBAction)sameAsArchiveButtonClicked:(NSButton *)sender {
    if (self.sameAsArchiveButton.state == NSOnState) {
        if (self.archiveFilePath) {
            [self setDestinationPathFromURL:self.archiveFilePath];
        } else {
            [self displayCorrectError];
        }
    } else {
        self.archiveDirectoryPath = nil;
        [self setDestinationPathFromURL:nil];
    }
}

- (IBAction)provisioningProfileInfoClicked:(NSButton *)sender {
    [self displayProvisioningProfileInformation];
}

- (IBAction)resetButtonClicked:(NSButton *)sender {
    [self resetObjects];
}

- (IBAction)provisioningProfilePopUpButtonClicked:(NSPopUpButton *)sender {
    self.provisioningProfileName = sender.title;
}

#pragma mark - Private

- (void)initialSetup {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = nil;
    if (paths.count > 0) {
        documentsDirectory = paths.firstObject;
    }
    [self.destinationPathControl setURL:[NSURL URLWithString:documentsDirectory]];
}

- (void)loadProvisioningProfiles {
    [self.provisioningPopUpButton removeAllItems];
    [self.provisioningPopUpButton addItemWithTitle:@"-- Select --"];

    self.provisioningProfileIndex = 0;
    [self nextProvisioningProfileName];
}

- (void)nextProvisioningProfileName {
    NSArray *provisioningProfiles = [self listOfProvisioningProfiles];
    if (self.provisioningProfileIndex >= provisioningProfiles.count) return;
    
    NSString *provisioning = provisioningProfiles[self.provisioningProfileIndex];
    NSString *path = [[kProvisioningProfileListPath stringByExpandingTildeInPath] stringByAppendingPathComponent:provisioning];
    
    __weak typeof(self) weakSelf = self;
    [self extractDataFromProvisioningProfileAtPath:path completionBlock:^(NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.provisioningProfileIndex++;
            [weakSelf nextProvisioningProfileName];
            if (data) {
                [weakSelf.provisioningPopUpButton addItemWithTitle:data[@"Name"]];
            }
        });
    }];
}

- (NSArray *)listOfProvisioningProfiles {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *dirContents = [fileManager contentsOfDirectoryAtPath:[kProvisioningProfileListPath stringByExpandingTildeInPath] error:&error];
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.mobileprovision'"];
    
    return [dirContents filteredArrayUsingPredicate:fltr];
}

- (void)setDestinationPathFromURL:(NSURL *)url {
    NSString *stringURL = [[[url absoluteString] stringByRemovingPercentEncoding] stringByDeletingLastPathComponent];
    [self.destinationPathControl setURL:[NSURL URLWithString:stringURL]];
}

- (void)resetObjects {
    self.archiveFilePath = nil;
    self.archiveDirectoryPath = nil;
    self.provisioningProfileName = nil;
    
    self.archiveLabel.stringValue = @"";
    self.projectNameTextField.stringValue = @"";
    [self.logLabel setHidden:YES];
}

- (void)createBuild {
    [self startAnimations];
    
    __block NSPipe *outPipe = [NSPipe pipe];
    __block NSPipe *errPipe = [NSPipe pipe];

    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"Build" ofType:@"sh"];
    NSTask *task = [NSTask new];
    [task setStandardInput:[NSPipe pipe]];
    [task setStandardOutput:outPipe];
    [task setStandardError:errPipe];
    [task setCurrentDirectoryPath:[self archiveDirectoryStringPath]];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:@[scriptPath,[self archiveStringPath],[self projectName],self.provisioningProfileName]];
    __weak typeof(self)weakSelf = self;
    [task setTerminationHandler:^(NSTask *task) {
        [weakSelf stopAnimations];
        
        NSString *output = [[NSString alloc] initWithData:[[outPipe fileHandleForReading] readDataToEndOfFile] encoding: NSUTF8StringEncoding];
        if ([output rangeOfString:@"EXPORT FAILED"].location != NSNotFound) {
            NSString *error = [[NSString alloc] initWithData:[[errPipe fileHandleForReading] readDataToEndOfFile] encoding: NSUTF8StringEncoding];
            if (error) {
                [weakSelf displayBuildError:error];
            }
        } else {
            [weakSelf displayBuildSuccessMessage];
        }
     }];
    [task launch];
}

- (void)extractDataFromProvisioningProfileAtPath:(NSString *)path completionBlock:(void (^)(NSDictionary *data))completion {
    __block NSPipe *outPipe = [NSPipe pipe];
    __block NSPipe *errPipe = [NSPipe pipe];
    
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"Provisioning" ofType:@"sh"];
    NSTask *task = [NSTask new];
    [task setStandardInput:[NSPipe pipe]];
    [task setStandardOutput:outPipe];
    [task setStandardError:errPipe];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:@[scriptPath,path]];

    [task setTerminationHandler:^(NSTask *task) {
        NSData *provisioningData = [[outPipe fileHandleForReading] readDataToEndOfFile];
        if (provisioningData) {
            NSString *plistError = nil;
            NSPropertyListFormat format;
            NSDictionary *plist = [NSPropertyListSerialization propertyListFromData:provisioningData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&plistError];
            if (completion) {
                completion(plist);
            }
        }
    }];
    [task launch];
}

- (void)startAnimations {
    self.logLabel.stringValue = @"Archiving...";
    [self.logLabel setHidden:NO];
    [self.spinner setHidden:NO];
    [self.spinner startAnimation:nil];
}

- (void)stopAnimations {
    self.logLabel.stringValue = @"Done!";
    [self.logLabel setHidden:NO];
    [self.spinner setHidden:YES];
    [self.spinner stopAnimation:nil];
}

- (NSString *)archiveStringPath {
    NSString *stringPath = [[self.archiveFilePath absoluteString] stringByRemovingPercentEncoding];
    return [stringPath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
}

- (NSString *)archiveDirectoryStringPath {
    NSString *stringPath = [[self.archiveDirectoryPath absoluteString] stringByRemovingPercentEncoding];
    return [stringPath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
}

- (NSString *)projectName {
    return self.projectNameTextField.stringValue;
}

- (BOOL)inputsAreValid {
    if (!self.archiveFilePath) return NO;
    
    if (!self.archiveDirectoryPath) return NO;
    
    if (!self.projectNameTextField.stringValue || self.projectNameTextField.stringValue.length == 0) return NO;
    
    if (!self.provisioningProfileName || self.provisioningProfileName.length == 0  || [self.provisioningProfileName isEqualToString:@"-- Select --"]) return NO;
    
    return YES;
}

- (void)displayCorrectError {
    NSString *message = @"An error has occurred. Please verify the information and try again.";
    if (!self.archiveFilePath) {
        message = @"Please select the archive file.";
        
    } else if (!self.archiveDirectoryPath) {
        message = @"Please select a directory to save the archive.";
        
    } else if (!self.projectNameTextField.stringValue || self.projectNameTextField.stringValue.length == 0) {
        message = @"Please enter a project name.";
        
    } else if (!self.provisioningProfileName || self.provisioningProfileName.length == 0 || [self.provisioningProfileName isEqualToString:@"-- Select --"]) {
        message = @"Please enter a provisioning profile.";
    }
    
    NSAlert *alert = [NSAlert new];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert setMessageText:@"Error while checking the provided data"];
    [alert setInformativeText:message];
    [alert runModal];
}

- (void)displayBuildError:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [NSAlert new];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:@"Error Creating IPA"];
        [alert setInformativeText:message];
        [alert runModal];
    });
}

- (void)displayProvisioningProfileInformation {
    NSAlert *alert = [NSAlert new];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert setMessageText:@"Provisioning Profile"];
    [alert setInformativeText:@"Your provisioning profile should match exactly the name of the provisioning profile you use to sign the build."];
    [alert runModal];
}

- (void)displayBuildSuccessMessage {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [NSAlert new];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:@"You are done!"];
        [alert setInformativeText:@"IPA created successfully"];
        [alert runModal];
    });
}

- (void)selectArchiveFileSuccess:(void (^)(NSURL *url))succes {
    NSString *url = [kArchivesPath stringByExpandingTildeInPath];
    NSURL *archivesURL = [NSURL URLWithString:url];
    __block NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    [panel setDirectoryURL:archivesURL];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            if (succes) {
                succes(panel.URLs.lastObject);
            }
        }
    }];
}

- (void)selectArchiveDirectorySuccess:(void (^)(NSURL *url))succes {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            if (succes) {
                succes(panel.URLs.lastObject);
            }
        }
    }];
}

@end
