#import "Calendar.h"
#import <Cordova/CDV.h>
#import <EventKitUI/EventKitUI.h>
#import <EventKit/EventKit.h>

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@implementation Calendar
@synthesize eventStore;
@synthesize interactiveCallbackId;

#pragma mark Initialization functions

- (void) pluginInitialize {
    [self initEventStoreWithCalendarCapabilities];
}

- (void) initEventStoreWithCalendarCapabilities {
  __block BOOL accessGranted = NO;
  EKEventStore* eventStoreCandidate = [[EKEventStore alloc] init];
  if([eventStoreCandidate respondsToSelector:@selector(requestAccessToEntityType:completion:)]) {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [eventStoreCandidate requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
      accessGranted = granted;
      dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  } else { // we're on iOS 5 or older
    accessGranted = YES;
  }
    
  if (accessGranted) {
    self.eventStore = eventStoreCandidate;
  }
}

#pragma mark Helper Functions

- (void) createEventWithCalendar:(CDVInvokedUrlCommand*)command
                       calendar: (EKCalendar *) calendar {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* title      = [options objectForKey:@"title"];
  NSString* location   = [options objectForKey:@"location"];
  NSString* notes      = [options objectForKey:@"notes"];
  NSNumber* startTime  = [options objectForKey:@"startTime"];
  NSNumber* endTime    = [options objectForKey:@"endTime"];

  [self.commandDelegate runInBackground: ^{
    NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
    NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];
    NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis

    EKEvent *myEvent = [EKEvent eventWithEventStore: self.eventStore];
    myEvent.title = title;
    myEvent.location = location;
    myEvent.notes = notes;
    myEvent.startDate = myStartDate;

    int duration = _endInterval - _startInterval;
    int moduloDay = duration % (60 * 60 * 24);
    if (moduloDay == 0) {
      myEvent.allDay = YES;
      myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval - 1];
    } else {
      myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];
    }
    myEvent.calendar = calendar;

    // if a custom reminder is required: use createCalendarWithOptions
    EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1 * 60 * 60];
    [myEvent addAlarm:reminder];

    NSError *error = nil;
    [self.eventStore saveEvent:myEvent span:EKSpanThisEvent error:&error];

    CDVPluginResult *pluginResult = nil;
    if (error) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
    } else {
      NSLog(@"Reached Success");
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (EKRecurrenceFrequency) toEKRecurrenceFrequency:(NSString*) recurrence {
  if ([recurrence isEqualToString:@"daily"]) {
    return EKRecurrenceFrequencyDaily;
  } else if ([recurrence isEqualToString:@"weekly"]) {
    return EKRecurrenceFrequencyWeekly;
  } else if ([recurrence isEqualToString:@"monthly"]) {
    return EKRecurrenceFrequencyMonthly;
  } else if ([recurrence isEqualToString:@"yearly"]) {
    return EKRecurrenceFrequencyYearly;
  }
  // default to daily, so invoke this method only when recurrence is set
  return EKRecurrenceFrequencyDaily;
}
- (void) modifyEventWithOptions:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* title      = [options objectForKey:@"title"];
  NSString* location   = [options objectForKey:@"location"];
  NSString* notes      = [options objectForKey:@"notes"];
  NSNumber* startTime  = [options objectForKey:@"startTime"];
  NSNumber* endTime    = [options objectForKey:@"endTime"];

  NSString* ntitle     = [options objectForKey:@"newTitle"];
  NSString* nlocation  = [options objectForKey:@"newLocation"];
  NSString* nnotes     = [options objectForKey:@"newNotes"];
  NSNumber* nstartTime = [options objectForKey:@"newStartTime"];
  NSNumber* nendTime   = [options objectForKey:@"newEndTime"];
  BOOL spanFuture = [[options objectForKey:@"spanFuture"] boolValue];
  NSLog(@"spanFuture is %d", spanFuture);
  // For some reason we need to reconnect to the event store.
  [self initEventStoreWithCalendarCapabilities];

  NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
  NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];

  NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis
  NSDate *myEndDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];

  NSDateFormatter *df = [[NSDateFormatter alloc] init];
  [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

  NSDictionary* calOptions = [options objectForKey:@"options"];
  NSString* calEventID = [calOptions objectForKey:@"id"];
  // the only search param we're currently matching against is the calendarName, so ignoring any passed reminder values etc
  NSString* calendarName = [calOptions objectForKey:@"calendarName"];
  [self.commandDelegate runInBackground: ^{
      CDVPluginResult *pluginResult = nil;
      NSArray *calendars = nil;

      if (calendarName == (id)[NSNull null]) {
          calendars = [self.eventStore calendarsForEntityType:EKEntityTypeEvent];
          if (calendars.count == 0) {
              CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
              [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
              return;
          }
      } else {
          EKCalendar * calendar = [self findEKCalendar:calendarName];

          if (calendar == nil) {
              CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
              [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
              return;
          } else {
              calendars = [NSArray arrayWithObject:calendar];
          }
      }
      if(calEventID == nil){
        //return error
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Did not get an eventIdentifier"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
      }
    
      NSArray *matchingEventsWithID = [self findEKEventsWithEventId:calEventID title:title location:location notes:notes startDate:myStartDate endDate:myEndDate calendars:calendars];
      EKEvent *event = [matchingEventsWithID lastObject]; // There should be only one.
      // Find matches
      NSError *error = NULL;
      EKEvent *theEvent = nil;
      if (spanFuture==1 && event.isDetached==FALSE) {
        
        [self.eventStore removeEvent:event span:EKSpanFutureEvents commit:YES error:&error];
        theEvent = [EKEvent eventWithEventStore: self.eventStore];
      }else{
        theEvent = event;
      }
    
    
      NSDictionary* newCalOptions = [options objectForKey:@"newOptions"];
      NSString* newCalendarName = [newCalOptions objectForKey:@"calendarName"];
      if (newCalendarName != (id)[NSNull null]) {
        theEvent.calendar = [self findEKCalendar:calendarName];
        if (theEvent.calendar == nil) {
          pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar passed in newOptions object"];
          [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
          return;
        }
      }

      if (ntitle) {
        theEvent.title = ntitle;
      }
      if (nlocation) {
        theEvent.location = nlocation;
      }
      if (nnotes) {
        theEvent.notes = nnotes;
      }
      if (nstartTime) {
        NSTimeInterval _nstartInterval = [nstartTime doubleValue] / 1000; // strip millis
        theEvent.startDate = [NSDate dateWithTimeIntervalSince1970:_nstartInterval];
      }
      if (nendTime) {
        NSTimeInterval _nendInterval = [nendTime doubleValue] / 1000; // strip millis
        theEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_nendInterval];
      }

      if (spanFuture==1 && event.isDetached==FALSE) {
        // Having an issue with detached events deleting all
        // of the alarms..
        for (EKAlarm *alarm in theEvent.alarms) {
          [theEvent removeAlarm:alarm];
        }

        NSNumber* firstReminderMinutes = [newCalOptions objectForKey:@"firstReminderMinutes"];
        if (firstReminderMinutes != (id)[NSNull null]) {
          EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*firstReminderMinutes.intValue*60];
          [theEvent addAlarm:reminder];
        }

        NSNumber* secondReminderMinutes = [newCalOptions objectForKey:@"secondReminderMinutes"];
        if (secondReminderMinutes != (id)[NSNull null]) {
          EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*secondReminderMinutes.intValue*60];
          [theEvent addAlarm:reminder];
        }
      }

      NSString* recurrence = [newCalOptions objectForKey:@"recurrence"];
      NSNumber* intervalAmount = [newCalOptions objectForKey:@"recurrenceInterval"];
      if(intervalAmount != nil && intervalAmount.integerValue >0 && 
          spanFuture == 1 && theEvent.isDetached != TRUE){ // There must be an interval amount to save the new recurrence.
        NSMutableDictionary * detailedRecurrence = [self createDetailedRecDictionary:newCalOptions];
        EKRecurrenceRule *rule = [[EKRecurrenceRule alloc] initRecurrenceWithFrequency: [self toEKRecurrenceFrequency:recurrence]
                                                                            interval: intervalAmount.integerValue
                                                                       daysOfTheWeek: detailedRecurrence[@"daysOfTheWeek"]
                                                                      daysOfTheMonth: detailedRecurrence[@"daysOfTheMonth"]
                                                                      monthsOfTheYear:detailedRecurrence[@"monthsOfTheYear"]
                                                                      weeksOfTheYear:detailedRecurrence[@"weeksOfTheYear"]
                                                                      daysOfTheYear:nil
                                                                        setPositions:detailedRecurrence[@"setPositions"]
                                                                                 end: nil];
        NSString* recurrenceEndTime = [newCalOptions objectForKey:@"recurrenceEndTime"];
        if (recurrenceEndTime != nil) {
          NSTimeInterval _recurrenceEndTimeInterval = [recurrenceEndTime doubleValue] / 1000; // strip millis
          NSDate *myRecurrenceEndDate = [NSDate dateWithTimeIntervalSince1970:_recurrenceEndTimeInterval];
          EKRecurrenceEnd *end = [EKRecurrenceEnd recurrenceEndWithEndDate:myRecurrenceEndDate];
          rule.recurrenceEnd = end;
        }
        [theEvent addRecurrenceRule:rule];
      }
      NSString* url = [newCalOptions objectForKey:@"url"];
      if (url != (id)[NSNull null]) {
        NSURL* myUrl = [NSURL URLWithString:url];
        theEvent.URL = myUrl;
      }

      // Now save the new details back to the store
      if(spanFuture == 1){
        [self.eventStore saveEvent:theEvent span:EKSpanFutureEvents error:&error];
      }else{
        [self.eventStore saveEvent:theEvent span:EKSpanThisEvent error:&error];
        // okay not try and save the alarms the detached event.
        for (EKAlarm *alarm in theEvent.alarms) {
          [theEvent removeAlarm:alarm];
        }

        NSNumber* firstReminderMinutes = [newCalOptions objectForKey:@"firstReminderMinutes"];
        if (firstReminderMinutes != (id)[NSNull null]) {
          EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*firstReminderMinutes.intValue*60];
          [theEvent addAlarm:reminder];
        }

        NSNumber* secondReminderMinutes = [newCalOptions objectForKey:@"secondReminderMinutes"];
        if (secondReminderMinutes != (id)[NSNull null]) {
          EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*secondReminderMinutes.intValue*60];
          [theEvent addAlarm:reminder];
        }
        // save again.
        [self.eventStore saveEvent:theEvent span:EKSpanThisEvent error:&error];
      }
      
      if(error){
        // Send error right away and don't proceed with saving the other updates, 
        // which depend on it saving correctly.
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
      }else{
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:theEvent.eventIdentifier];
      }
      
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];

}
- (void) deleteEventFromCalendar:(CDVInvokedUrlCommand*)command
                       calendar: (EKCalendar *) calendar {

  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* title      = [options objectForKey:@"title"];
  NSString* location   = [options objectForKey:@"location"];
  NSString* notes      = [options objectForKey:@"notes"];
  NSNumber* startTime  = [options objectForKey:@"startTime"];
  NSNumber* endTime    = [options objectForKey:@"endTime"];

  [self.commandDelegate runInBackground: ^{
    NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
    NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];

    NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis
    NSDate *myEndDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];

    NSArray *calendars = [NSArray arrayWithObject:calendar];
    NSArray *matchingEvents = [self findEKEventsWithTitle:title location:location notes:notes startDate:myStartDate endDate:myEndDate calendars:calendars];

    NSError *error = NULL;
    for (EKEvent * event in matchingEvents) {
      // NOTE: as per issue #150 you can delete this event AND future events by passing span:EKSpanFutureEvents
      [self.eventStore removeEvent:event span:EKSpanThisEvent error:&error];
    }

    CDVPluginResult *pluginResult = nil;
    if (error) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
    } else {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[@"Deleted from " stringByAppendingString:calendar.title]];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (NSArray*) findEKEventsWithTitle: (NSString *)title
                        location: (NSString *)location
                           notes: (NSString *)notes
                       startDate: (NSDate *)startDate
                         endDate: (NSDate *)endDate
                       calendars: (NSArray*)calendars {

  NSMutableArray *predicateStrings = [NSMutableArray arrayWithCapacity:3];
  if (title != (id)[NSNull null] && title.length > 0) {
    title = [title stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    [predicateStrings addObject:[NSString stringWithFormat:@"title contains[c] '%@'", title]];
  }
  if (location != (id)[NSNull null] && location.length > 0) {
    location = [location stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    [predicateStrings addObject:[NSString stringWithFormat:@"location contains[c] '%@'", location]];
  }
  if (notes != (id)[NSNull null] && notes.length > 0) {
    notes = [notes stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    [predicateStrings addObject:[NSString stringWithFormat:@"notes contains[c] '%@'", notes]];
  }

  NSString *predicateString = [predicateStrings componentsJoinedByString:@" AND "];

  NSPredicate *matches;
  NSArray  *datedEvents, *matchingEvents;

  if (predicateString.length > 0) {
    matches = [NSPredicate predicateWithFormat:predicateString];

    datedEvents = [self.eventStore eventsMatchingPredicate:[eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendars]];

    matchingEvents = [datedEvents filteredArrayUsingPredicate:matches];
  } else {

    datedEvents = [self.eventStore eventsMatchingPredicate:[eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendars]];

    matchingEvents = datedEvents;
  }

  return matchingEvents;
}

- (NSArray*) findEKEventsWithEventId: (NSString *)eventId
                           title: (NSString *)title
                        location: (NSString *)location
                           notes: (NSString *)notes
                       startDate: (NSDate *)startDate
                         endDate: (NSDate *)endDate
                       calendars: (NSArray*)calendars {
  // This function is identical to findEKEventsWithTitle except
  // it adds the eventId to the event critera, gets an instance
  // based on the other attibutes passed in.
                        NSLog(@"Parameter ID  = %@", eventId);
  NSMutableArray *predicateStrings = [NSMutableArray arrayWithCapacity:3];
  if (title != (id)[NSNull null] && title.length > 0) {
    title = [title stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    [predicateStrings addObject:[NSString stringWithFormat:@"title contains[c] '%@'", title]];
  }
  if (location != (id)[NSNull null] && location.length > 0) {
    location = [location stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    [predicateStrings addObject:[NSString stringWithFormat:@"location contains[c] '%@'", location]];
  }
  if (eventId != (id)[NSNull null] && eventId.length > 0) {
    eventId = [eventId stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    [predicateStrings addObject:[NSString stringWithFormat:@"eventIdentifier like[c] '%@'", eventId]];
  }
  if (notes != (id)[NSNull null] && notes.length > 0) {
    notes = [notes stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    [predicateStrings addObject:[NSString stringWithFormat:@"notes contains[c] '%@'", notes]];
  }

  NSString *predicateString = [predicateStrings componentsJoinedByString:@" AND "];

  NSPredicate *matches;
  NSArray  *datedEvents, *matchingEvents;

  if (predicateString.length > 0) {
    matches = [NSPredicate predicateWithFormat:predicateString];

    datedEvents = [self.eventStore eventsMatchingPredicate:[eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendars]];

    matchingEvents = [datedEvents filteredArrayUsingPredicate:matches];
  } else {

    datedEvents = [self.eventStore eventsMatchingPredicate:[eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendars]];

    matchingEvents = datedEvents;
  }
  NSArray *sortedResults = [matchingEvents sortedArrayUsingSelector:@selector(compareStartDateWithEvent:)];
  // NSMutableArray *idMatchingEvents = [[NSMutableArray alloc] init];
  // NSLog(@"Parameter ID  = %@", eventId);
  // for(EKEvent* event in sortedResults){
  //   NSLog(@"Found IDs  = %@", event.eventIdentifier);
    
  //   if ([event.eventIdentifier isEqualToString: eventId]) {
  //     NSLog(@"end id  = %@", event.eventIdentifier);
  //     [idMatchingEvents addObject:event];

  //   }
  // }

  //return idMatchingEvents;
  return sortedResults;

}

- (EKCalendar*) findEKCalendar: (NSString *)calendarName {
  for (EKCalendar *thisCalendar in [self.eventStore calendarsForEntityType:EKEntityTypeEvent]){
    NSLog(@"Calendar: %@", thisCalendar.title);
    if ([thisCalendar.title isEqualToString:calendarName]) {
      return thisCalendar;
    }
  }
  NSLog(@"No match found for calendar with name: %@", calendarName);
  return nil;
}

- (EKSource*) findEKSource {
  // if iCloud is on, it hides the local calendars, so check for iCloud first
  for (EKSource *source in self.eventStore.sources) {
    if (source.sourceType == EKSourceTypeCalDAV && [source.title isEqualToString:@"iCloud"]) {
      return source;
    }
  }

  // ok, not found.. so it's a local calendar
  for (EKSource *source in self.eventStore.sources) {
    if (source.sourceType == EKSourceTypeLocal) {
      return source;
    }
  }
  return nil;
}

- (NSMutableArray*) eventsToDataArray: (NSArray*)matchingEvents {
  NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:matchingEvents.count];

  NSDateFormatter *df = [[NSDateFormatter alloc] init];
  [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

  for (EKEvent * event in matchingEvents) {
    NSMutableDictionary *entry = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                  event.title, @"title",
                                  event.calendar.title, @"calendar",
                                  [df stringFromDate:event.startDate], @"startDate",
                                  [df stringFromDate:event.endDate], @"endDate",
                                  [df stringFromDate:event.lastModifiedDate], @"lastModifiedDate",
                                  nil];
    // optional fields
    if (event.location != nil) {
      [entry setObject:event.location forKey:@"location"];
    }
    if (event.notes != nil) {
      [entry setObject:event.notes forKey:@"message"];
    }
    if (event.attendees != nil) {
      NSMutableArray * attendees = [[NSMutableArray alloc] init];
      for (EKParticipant * participant in event.attendees) {

        NSString *role = [[NSArray arrayWithObjects:@"Unknown", @"Required", @"Optional", @"Chair", @"Non Participant", nil] objectAtIndex:participant.participantRole];
        NSString *status = [[NSArray arrayWithObjects:@"Unknown", @"Pending", @"Accepted", @"Declined", @"Tentative", @"Delegated", @"Completed", @"In Process", nil] objectAtIndex:participant.participantStatus];
        NSString *type = [[NSArray arrayWithObjects:@"Unknown", @"Person", @"Room", @"Resource", @"Group", nil] objectAtIndex:participant.participantType];

        NSMutableDictionary *attendeeEntry = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                              participant.name, @"name",
                                              [participant.URL absoluteString], @"URL",
                                              status, @"status",
                                              type, @"type",
                                              role, @"role",
                                              nil];
        [attendees addObject:attendeeEntry];
      }
      [entry setObject:attendees forKey:@"attendees"];
    }
    if(event.recurrenceRules!=nil){
      NSMutableArray * recurrences = [[NSMutableArray alloc] init];
      for (EKRecurrenceRule * recurrence in event.recurrenceRules) {
            NSString *frequency = nil;
            switch(recurrence.frequency) {
            case EKRecurrenceFrequencyDaily:
                frequency = @"daily";
                break;
            case EKRecurrenceFrequencyWeekly:
                frequency = @"weekly";
                break;
            case EKRecurrenceFrequencyMonthly:
                frequency = @"monthly";
                break;
            case EKRecurrenceFrequencyYearly:
                frequency = @"yearly";
                break;
            }
        NSMutableDictionary *recurrenceEntry = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                              frequency, @"frequency",
                                              @(recurrence.interval), @"interval",
                                              [df stringFromDate:recurrence.recurrenceEnd.endDate], @"endDate",
                                              nil];

        if([recurrence.daysOfTheWeek count] >0){
          NSMutableArray * daysOfTheWeek = [[NSMutableArray alloc] init];
          for(EKRecurrenceDayOfWeek *day in recurrence.daysOfTheWeek){
            [daysOfTheWeek addObject: [NSNumber numberWithInt:day.dayOfTheWeek]];
          }
          [recurrenceEntry setObject:daysOfTheWeek forKey:@"daysOfTheWeek"];
        }
        if([recurrence.daysOfTheMonth count] >0){
          NSMutableArray * daysOfTheMonth = [[NSMutableArray alloc] init];
          for(NSNumber *day in recurrence.daysOfTheMonth){
            [daysOfTheMonth addObject:day];
          }
          [recurrenceEntry setObject:daysOfTheMonth forKey:@"daysOfTheMonth"];
        }
        if([recurrence.monthsOfTheYear count] >0){
          NSMutableArray * monthsOfTheYear = [[NSMutableArray alloc] init];
          for(NSNumber *month in recurrence.monthsOfTheYear){
            [monthsOfTheYear addObject:month];
          }
          [recurrenceEntry setObject:monthsOfTheYear forKey:@"monthsOfTheYear"];
        }
        if([recurrence.weeksOfTheYear count] >0){
          NSMutableArray * weeksOfTheYear = [[NSMutableArray alloc] init];
          for(NSNumber *week in recurrence.weeksOfTheYear){
            [weeksOfTheYear addObject:week];
          }
          [recurrenceEntry setObject:weeksOfTheYear forKey:@"weeksOfTheYear"];
        }
        if([recurrence.setPositions count] >0){
          NSMutableArray * setPositions = [[NSMutableArray alloc] init];
          for(NSNumber *position in recurrence.setPositions){
            [setPositions addObject:position];
          }
          [recurrenceEntry setObject:setPositions forKey:@"setPositions"];
        }
        [recurrences addObject:recurrenceEntry];
      }
      [entry setObject:recurrences forKey:@"recurrences"];
    }
    if(event.alarms!=nil){
      //NSMutableArray * alarms = [[NSMutableArray alloc] init];
      NSUInteger index = 0;
      /*NSMutableDictionary *alarmEntry = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                          nil, @"firstReminderMinutes",
                                          nil,@"secondReminderMinutes"
                                          nil];*/
      NSMutableDictionary *alarmEntry = [[NSMutableDictionary alloc] init];
      if([event.alarms count] > 1){
        if(event.alarms[0].relativeOffset < event.alarms[1].relativeOffset){
          [alarmEntry setObject:@(event.alarms[1].relativeOffset/60) forKey:@"firstReminderMinutes"];
          [alarmEntry setObject:@(event.alarms[0].relativeOffset/60) forKey:@"secondReminderMinutes"];
        }else{
          [alarmEntry setObject:@(event.alarms[0].relativeOffset/60) forKey:@"firstReminderMinutes"];
          [alarmEntry setObject:@(event.alarms[1].relativeOffset/60) forKey:@"secondReminderMinutes"];
        }
      }
      else if([event.alarms count] == 1){
          [alarmEntry setObject:@(event.alarms[0].relativeOffset/60) forKey:@"firstReminderMinutes"];
      }
      [entry setObject:alarmEntry forKey:@"alarms"];
    }
    if(event.isDetached!=nil){
      NSNumber *detached = @NO;
      if(event.isDetached){
        detached = @YES;
      }
      [entry setObject:detached forKey:@"isDetached"];
    }
    [entry setObject:event.eventIdentifier forKey:@"id"];
    [results addObject:entry];
  }
  return results;
}
- (NSMutableDictionary*) createDetailedRecDictionary: (NSDictionary*)calOptions {
  NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
  NSMutableArray *daysOfWeekArray = [[NSMutableArray alloc] init];
    for(NSNumber *day in calOptions[@"daysOfTheWeek"]){
      [daysOfWeekArray addObject:[EKRecurrenceDayOfWeek dayOfWeek:day.integerValue]];
    }
  [result setObject:daysOfWeekArray forKey:@"daysOfTheWeek"];

  NSMutableArray *daysOfMonthArray = [[NSMutableArray alloc] init];
    for(NSNumber *day in calOptions[@"daysOfTheMonth"]){
      //NSLog(@"month day = %@", day.stringValue);
      [daysOfMonthArray addObject:day];
    }
  [result setObject:daysOfMonthArray forKey:@"daysOfTheMonth"];

  NSMutableArray *monthsOfTheYear = [[NSMutableArray alloc] init];
    for(NSNumber *month in calOptions[@"monthsOfTheYear"]){
      [monthsOfTheYear addObject:month];
    }
  [result setObject:monthsOfTheYear forKey:@"monthsOfTheYear"];

  NSMutableArray *weeksOfTheYear = [[NSMutableArray alloc] init];
    for(NSNumber *week in calOptions[@"weeksOfTheYear"]){
      [weeksOfTheYear addObject:week];
    }
  [result setObject:weeksOfTheYear forKey:@"weeksOfTheYear"];

  NSMutableArray *setPositions = [[NSMutableArray alloc] init];
    for(NSNumber *position in calOptions[@"setPositions"]){
      [setPositions addObject:position];
    }
  [result setObject:setPositions forKey:@"setPositions"];

  return result;
}

#pragma mark Cordova functions

- (void) openCalendar:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSNumber* date = [options objectForKey:@"date"];

  [self.commandDelegate runInBackground: ^{
    NSTimeInterval _startInterval = [date doubleValue] / 1000; // strip millis
    NSDate *openDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];
    NSInteger interval = [openDate timeIntervalSinceReferenceDate];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"calshow:%ld", interval]];
    [[UIApplication sharedApplication] openURL:url];
  }];
}

- (void) listCalendars:(CDVInvokedUrlCommand*)command {
  [self.commandDelegate runInBackground: ^{
    NSArray * calendars = [self.eventStore calendarsForEntityType:EKEntityTypeEvent];
    NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:calendars.count];
    for (EKCalendar *thisCalendar in calendars) {
      NSString *type = [[NSArray arrayWithObjects:@"Local", @"CalDAV", @"Exchange", @"Subscription", @"Birthday", @"Mail", nil] objectAtIndex:thisCalendar.type];
      NSMutableDictionary *entry = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                    thisCalendar.calendarIdentifier, @"id",
                                    thisCalendar.title, @"name",
                                    type, @"type",
                                    nil];
      [finalResults addObject:entry];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:finalResults];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (void) listEventsInRange:(CDVInvokedUrlCommand*)command {
}

- (void)createEventWithOptions:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];

  NSString* title      = [options objectForKey:@"title"];
  NSString* location   = [options objectForKey:@"location"];
  NSString* notes      = [options objectForKey:@"notes"];
  NSNumber* startTime  = [options objectForKey:@"startTime"];
  NSNumber* endTime    = [options objectForKey:@"endTime"];

  NSDictionary* calOptions = [options objectForKey:@"options"];
  NSNumber* firstReminderMinutes = [calOptions objectForKey:@"firstReminderMinutes"];
  NSNumber* secondReminderMinutes = [calOptions objectForKey:@"secondReminderMinutes"];
  NSString* recurrence = [calOptions objectForKey:@"recurrence"];
  NSString* recurrenceEndTime = [calOptions objectForKey:@"recurrenceEndTime"];
  NSNumber* recurrenceIntervalAmount = [calOptions objectForKey:@"recurrenceInterval"];
  NSString* calendarName = [calOptions objectForKey:@"calendarName"];
  NSString* url = [calOptions objectForKey:@"url"];

  [self.commandDelegate runInBackground: ^{
    EKEvent *myEvent = [EKEvent eventWithEventStore: self.eventStore];
    if (url != (id)[NSNull null]) {
      NSURL* myUrl = [NSURL URLWithString:url];
      myEvent.URL = myUrl;
    }

    NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
    NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];

    NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis

    myEvent.title = title;
    myEvent.location = location;
    myEvent.notes = notes;
    myEvent.startDate = myStartDate;

    int duration = _endInterval - _startInterval;
    int moduloDay = duration % (60*60*24);
    if (moduloDay == 0) {
      myEvent.allDay = YES;
      myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval-1];
    } else {
      myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];
    }

    EKCalendar* calendar = nil;
    CDVPluginResult *pluginResult = nil;

    if (calendarName == (id)[NSNull null]) {
      calendar = self.eventStore.defaultCalendarForNewEvents;
      if (calendar == nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
      }
    } else {
      calendar = [self findEKCalendar:calendarName];
      if (calendar == nil) {
        // create it
        calendar = [EKCalendar calendarForEntityType:EKEntityTypeEvent eventStore:self.eventStore];
        calendar.title = calendarName;
        calendar.source = [self findEKSource];
        NSError* error;
        [self.eventStore saveCalendar:calendar commit:YES error:&error];
        if (error != nil) {
          NSLog(@"could not create calendar, error: %@", error.description);
          pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Calendar could not be found nor created. Is access to the Calendar blocked for this app?"];
          [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
          return;
        }
      }
    }
    myEvent.calendar = calendar;
    if (firstReminderMinutes != (id)[NSNull null]) {
      EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*firstReminderMinutes.intValue*60];
      [myEvent addAlarm:reminder];
    }
    if (secondReminderMinutes != (id)[NSNull null]) {
      EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*secondReminderMinutes.intValue*60];
      [myEvent addAlarm:reminder];
    }

    if (recurrence != (id)[NSNull null] && recurrenceIntervalAmount.integerValue>0) {
      NSMutableDictionary * detailedRecurrence = [self createDetailedRecDictionary:calOptions];
      
      EKRecurrenceRule *rule = [[EKRecurrenceRule alloc] initRecurrenceWithFrequency: [self toEKRecurrenceFrequency:recurrence]
                                                                            interval: recurrenceIntervalAmount.integerValue
                                                                       daysOfTheWeek: detailedRecurrence[@"daysOfTheWeek"]
                                                                      daysOfTheMonth: detailedRecurrence[@"daysOfTheMonth"]
                                                                      monthsOfTheYear:detailedRecurrence[@"monthsOfTheYear"]
                                                                      weeksOfTheYear:detailedRecurrence[@"weeksOfTheYear"]
                                                                      daysOfTheYear:nil
                                                                        setPositions:detailedRecurrence[@"setPositions"]
                                                                                 end: nil];
      if (recurrenceEndTime != nil) {
        NSTimeInterval _recurrenceEndTimeInterval = [recurrenceEndTime doubleValue] / 1000; // strip millis
        NSDate *myRecurrenceEndDate = [NSDate dateWithTimeIntervalSince1970:_recurrenceEndTimeInterval];
        EKRecurrenceEnd *end = [EKRecurrenceEnd recurrenceEndWithEndDate:myRecurrenceEndDate];
        rule.recurrenceEnd = end;
      }
      [myEvent addRecurrenceRule:rule];
    }

    NSError *error = nil;
    [self.eventStore saveEvent:myEvent span:EKSpanThisEvent commit:YES error:&error];

    if (error) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
    } else {
      //pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:myEvent.calendarItemIdentifier];
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:myEvent.eventIdentifier];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (void) createEventInteractively:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];

  NSString* title      = [options objectForKey:@"title"];
  NSString* location   = [options objectForKey:@"location"];
  NSString* notes      = [options objectForKey:@"notes"];
  NSNumber* startTime  = [options objectForKey:@"startTime"];
  NSNumber* endTime    = [options objectForKey:@"endTime"];

  NSDictionary* calOptions = [options objectForKey:@"options"];
  NSNumber* firstReminderMinutes = [calOptions objectForKey:@"firstReminderMinutes"];
  NSNumber* secondReminderMinutes = [calOptions objectForKey:@"secondReminderMinutes"];
  NSString* recurrence = [calOptions objectForKey:@"recurrence"];
  NSString* recurrenceEndTime = [calOptions objectForKey:@"recurrenceEndTime"];
  NSString* calendarName = [calOptions objectForKey:@"calendarName"];
  NSString* url = [calOptions objectForKey:@"url"];
  NSNumber* intervalAmount = [calOptions objectForKey:@"recurrenceInterval"];

  EKEvent *myEvent = [EKEvent eventWithEventStore: self.eventStore];
  if (url != (id)[NSNull null]) {
    NSURL* myUrl = [NSURL URLWithString:url];
    myEvent.URL = myUrl;
  }

  if (startTime != (id)[NSNull null]) {
  NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
  NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];
    myEvent.startDate = myStartDate;
  }

  if (endTime != (id)[NSNull null]) {
  NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis
    if (startTime != (id)[NSNull null]) {
      NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
      int duration = _endInterval - _startInterval;
      int moduloDay = duration % (60 * 60 * 24);
      if (moduloDay == 0) {
        myEvent.allDay = YES;
        myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval - 1];
      } else {
        myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];
      }
    } else {
      myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];
    }
  }

  myEvent.title = title;
  myEvent.location = location;
  myEvent.notes = notes;

  [self.commandDelegate runInBackground: ^{
    EKCalendar* calendar = nil;

    if (calendarName == (id)[NSNull null]) {
      calendar = self.eventStore.defaultCalendarForNewEvents;
      if (calendar == nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
      }
    } else {
      calendar = [self findEKCalendar:calendarName];
      if (calendar == nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
      }
    }
    myEvent.calendar = calendar;

    if (firstReminderMinutes != (id)[NSNull null]) {
      EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1 * firstReminderMinutes.intValue * 60];
      [myEvent addAlarm:reminder];
    }

    if (secondReminderMinutes != (id)[NSNull null]) {
      EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1 * secondReminderMinutes.intValue * 60];
      [myEvent addAlarm:reminder];
    }

    if (recurrence != (id)[NSNull null]) {
      [self.commandDelegate runInBackground: ^{
        EKRecurrenceRule *rule = [[EKRecurrenceRule alloc] initRecurrenceWithFrequency: [self toEKRecurrenceFrequency:recurrence]
                                                                              interval: intervalAmount.integerValue
                                                                                   end: nil];
        if (recurrenceEndTime != nil) {
          NSTimeInterval _recurrenceEndTimeInterval = [recurrenceEndTime doubleValue] / 1000; // strip millis
          NSDate *myRecurrenceEndDate = [NSDate dateWithTimeIntervalSince1970:_recurrenceEndTimeInterval];
          EKRecurrenceEnd *end = [EKRecurrenceEnd recurrenceEndWithEndDate:myRecurrenceEndDate];
          rule.recurrenceEnd = end;
        }
        [myEvent addRecurrenceRule:rule];
      }];
    }

    self.interactiveCallbackId = command.callbackId;

    EKEventEditViewController* controller = [[EKEventEditViewController alloc] init];
    controller.event = myEvent;
    controller.eventStore = self.eventStore;
    controller.editViewDelegate = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.viewController presentViewController:controller animated:YES completion:nil];
    });
  }];
}

- (void) deleteEventFromNamedCalendarWithID:(CDVInvokedUrlCommand*)command {
  // This is similar to deleteEventFromNamedCalendar, but an id is used to 
  // to find the event & there is the option to delete future events.
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* calendarName = [options objectForKey:@"calendarName"];
  EKCalendar* calendar = [self findEKCalendar:calendarName];
  NSString* title      = [options objectForKey:@"title"];
  NSString* location   = [options objectForKey:@"location"];
  NSString* notes      = [options objectForKey:@"notes"];
  NSNumber* startTime  = [options objectForKey:@"startTime"];
  NSNumber* endTime    = [options objectForKey:@"endTime"];
  NSString* eventId    = [options objectForKey:@"id"];
  BOOL spanFuture = [[options objectForKey:@"spanFuture"] boolValue];
  // For some reason we need to reconnect to the event store.
  //self.eventStore = [[EKEventStore alloc] init];
  [self initEventStoreWithCalendarCapabilities];


  NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
  NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];
  NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis
  NSDate *myEndDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];
  [self.commandDelegate runInBackground: ^{
    CDVPluginResult *pluginResult =nil;
    if (calendar == nil) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
    } else {
      NSArray *calendars = [NSArray arrayWithObject:calendar];
      NSArray *matchingEventsWithID = [self findEKEventsWithEventId:eventId title:title location:location notes:notes startDate:myStartDate endDate:myEndDate calendars:calendars];
      EKEvent *event = [matchingEventsWithID lastObject]; // There should be only one.
      NSError *error = NULL;
      if(spanFuture==1){
        [self.eventStore removeEvent:event span:EKSpanFutureEvents commit:YES error:&error];
      }else{
        [self.eventStore removeEvent:event span:EKSpanThisEvent commit:YES error:&error];
      }
      if (error) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
      } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:event.eventIdentifier];
      }
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (void) deleteEventFromNamedCalendar:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* calendarName = [options objectForKey:@"calendarName"];
  EKCalendar* calendar = [self findEKCalendar:calendarName];

  if (calendar == nil) {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  } else {
    [self deleteEventFromCalendar:command calendar:calendar];
    NSString *msg = [@"Deleted from " stringByAppendingString:calendar.title];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:msg];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }
}


- (void) deleteEvent:(CDVInvokedUrlCommand*)command {
  EKCalendar* calendar = self.eventStore.defaultCalendarForNewEvents;

  if (calendar == nil) {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  } else {
    [self deleteEventFromCalendar:command calendar: calendar];
  }
}

- (void) findAllEventsInNamedCalendar:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* calendarName = [options objectForKey:@"calendarName"];
  EKCalendar* calendar = [self findEKCalendar:calendarName];
  CDVPluginResult *pluginResult = nil;

  if (calendar == nil) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
  } else {
    NSDate* endDate =  [NSDate dateWithTimeIntervalSinceNow:[[NSDate distantFuture] timeIntervalSinceReferenceDate]];
    NSArray *calendarArray = [NSArray arrayWithObject:calendar];
    NSPredicate *fetchCalendarEvents = [eventStore predicateForEventsWithStartDate:[NSDate date] endDate:endDate calendars:calendarArray];
    NSArray *matchingEvents = [eventStore eventsMatchingPredicate:fetchCalendarEvents];
    NSMutableArray * eventsDataArray = [self eventsToDataArray:matchingEvents];

    pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:eventsDataArray];
  }
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
- (void) findAllEventsInNamedCalendarForTests:(CDVInvokedUrlCommand*)command {
  // This is a reworking of findAllEventsInNamedCalendar for test.
  // Because you can only search by four year intervals:
  // findAllEventsInNamedCalendar only searches for present to future events.
  // Many of the test cases are now in the past...
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* calendarName = [options objectForKey:@"calendarName"];
  EKCalendar* calendar = [self findEKCalendar:calendarName];
  CDVPluginResult *pluginResult = nil;

  if (calendar == nil) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
  } else {
    NSDateComponents *dateInPast  =[[NSDateComponents alloc] init];
    [dateInPast setYear: 2015];
    [dateInPast setDay: 1];
    [dateInPast setMonth:1];
    NSCalendar *g = [[ NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate *startDate = [g dateFromComponents:dateInPast];
    NSDateComponents *dateInFuture  =[[NSDateComponents alloc] init];
    [dateInFuture setYear: 2018];
    [dateInFuture setDay: 1];
    [dateInFuture setMonth:1];
    NSDate *endDate = [g dateFromComponents:dateInFuture];
    NSLog(@"%@", endDate);
    NSArray *calendarArray = [NSArray arrayWithObject:calendar];
    NSPredicate *fetchCalendarEvents = [eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendarArray];
    NSArray *matchingEvents = [eventStore eventsMatchingPredicate:fetchCalendarEvents];
    NSMutableArray * eventsDataArray = [self eventsToDataArray:matchingEvents];

    pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:eventsDataArray];
  }
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void) findEventWithOptions:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* title      = [options objectForKey:@"title"];
  NSString* location   = [options objectForKey:@"location"];
  NSString* notes      = [options objectForKey:@"notes"];
  NSNumber* startTime  = [options objectForKey:@"startTime"];
  NSNumber* endTime    = [options objectForKey:@"endTime"];

  // actually the only option we're currently using is calendarName
  NSDictionary* calOptions = [options objectForKey:@"options"];
  NSString* calEventID = [calOptions objectForKey:@"id"];
  NSString* calendarName = [calOptions objectForKey:@"calendarName"];
  [self.commandDelegate runInBackground: ^{
    NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
    NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];
    NSDate* myEndDate;
    CDVPluginResult *pluginResult;
    NSError* error;
    if ([endTime doubleValue] > 0) {
      NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis
      myEndDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];
    } else {
      // an enddate is mandatory for iOS, so using now+1y if it's not passed in
      NSDateComponents *oneYearFromNowComponents = [[NSDateComponents alloc] init];
      oneYearFromNowComponents.year = 1;
      myEndDate = [[NSCalendar currentCalendar] dateByAddingComponents:oneYearFromNowComponents
                                                                toDate:[NSDate date]
                                                               options:0];
    }

    NSArray* calendars = nil;

    if (calendarName == (id)[NSNull null]) {
        calendars = [self.eventStore calendarsForEntityType:EKEntityTypeEvent];
      if (calendars.count == 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
      }
    } else {
      EKCalendar * calendar = [self findEKCalendar:calendarName];

      if (calendar == nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
      }else{
        calendars = [NSArray arrayWithObject:calendar];
      }
    }

    // Find matches
    EKCalendarItem *theEvent;
    if (calEventID != nil) {
      theEvent = [self.eventStore calendarItemWithIdentifier:calEventID];
    }

    NSArray *matchingEvents;

    if (theEvent == nil) {
      matchingEvents = [self findEKEventsWithTitle:title location:location notes:notes startDate:myStartDate endDate:myEndDate calendars:calendars];
    } else {
      matchingEvents = [NSArray arrayWithObject:theEvent];
    }

    NSMutableArray * eventsDataArray = [self eventsToDataArray:matchingEvents];
    pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:eventsDataArray];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}


- (void) createCalendar:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* calendarName = [options objectForKey:@"calendarName"];
  NSString* hexColor = [options objectForKey:@"calendarColor"];

  [self.commandDelegate runInBackground: ^{
    EKCalendar *cal = [self findEKCalendar:calendarName];
    CDVPluginResult* pluginResult = nil;
    NSLog(@"calendar name to create: %@", calendarName);
    if (cal == nil) {
      cal = [EKCalendar calendarForEntityType:EKEntityTypeEvent eventStore:self.eventStore];
      cal.title = calendarName;
      if (hexColor != (id)[NSNull null]) {
        UIColor *theColor = [self colorFromHexString:hexColor];
        cal.CGColor = theColor.CGColor;
      }
      cal.source = [self findEKSource];

      // if the user did not allow permission to access the calendar, the error Object will be filled
      NSError* error;
      [self.eventStore saveCalendar:cal commit:YES error:&error];
      if (error == nil) {
        NSLog(@"created calendar: %@", cal.title);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:cal.calendarIdentifier];
      } else {
        NSLog(@"could not create calendar, error: %@", error.description);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Calendar could not be created. Is access to the Calendar blocked for this app?"];
      }
    } else {
      // ok, it already exists
      pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsString:@"OK, Calendar already exists"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

// Assumes input like "#00FF00" (#RRGGBB)
- (UIColor*) colorFromHexString:(NSString*) hexString {
  unsigned rgbValue = 0;
  NSScanner *scanner = [NSScanner scannerWithString:hexString];
  [scanner setScanLocation:1]; // bypass '#' character
  [scanner scanHexInt:&rgbValue];
  return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16) / 255.0 green:((rgbValue & 0xFF00) >> 8) / 255.0 blue:(rgbValue & 0xFF) / 255.0 alpha:1.0];
}

- (void) deleteCalendar:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  NSString* calendarName = [options objectForKey:@"calendarName"];

  [self.commandDelegate runInBackground: ^{
    EKCalendar *thisCalendar = [self findEKCalendar:calendarName];
    CDVPluginResult* pluginResult = nil;

    if (thisCalendar == nil) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    } else {
      NSError *error;
      [eventStore removeCalendar:thisCalendar commit:YES error:&error];

      if (error) {
        NSLog(@"Error in deleteCalendar: %@", error.localizedDescription);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
      } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      }
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (void) eventEditViewController:(EKEventEditViewController*)controller didCompleteWithAction:(EKEventEditViewAction) action {
  NSError *error = nil;
  CDVPluginResult *pluginResult = nil;

  switch (action) {
    case EKEventEditViewActionCanceled:
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
      break;

    case EKEventEditViewActionSaved:
      [controller.eventStore saveEvent:controller.event span:EKSpanThisEvent error:&error];
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:controller.event.calendarItemIdentifier];
      break;

    case EKEventEditViewActionDeleted:
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
      break;

    default:
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
      break;
  }

  [controller dismissViewControllerAnimated:YES completion:nil];

  if (error) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
  }
  [self.commandDelegate sendPluginResult:pluginResult callbackId:self.interactiveCallbackId];
}


/* There is no distingtion between read and write access in iOS */
- (void)hasReadPermission:(CDVInvokedUrlCommand*)command {
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:(self.eventStore != nil)];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)requestReadPermission:(CDVInvokedUrlCommand*)command {
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:[self requestCalendarAccess]];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)hasWritePermission:(CDVInvokedUrlCommand*)command {
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:(self.eventStore != nil)];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)requestWritePermission:(CDVInvokedUrlCommand*)command {
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:[self requestCalendarAccess]];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)hasReadWritePermission:(CDVInvokedUrlCommand*)command {
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:(self.eventStore != nil)];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)requestReadWritePermission:(CDVInvokedUrlCommand*)command {
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:[self requestCalendarAccess]];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(CDVCommandStatus)requestCalendarAccess{
    [self initEventStoreWithCalendarCapabilities];
    return (self.eventStore != nil) ? CDVCommandStatus_OK : CDVCommandStatus_ERROR;
}


@end
