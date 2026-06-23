#ifndef CGSPrivate_h
#define CGSPrivate_h

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

int _CGSDefaultConnection(void);
id  CGSCopyManagedDisplaySpaces(int conn);
id  CGSCopyActiveMenuBarDisplayIdentifier(int conn);

#endif /* CGSPrivate_h */
