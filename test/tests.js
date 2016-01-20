  "use strict";

exports.defineAutoTests = function() {
  var fail = function (done) {
    expect(true).toBe(false);
    done();
  },
  succeed = function (done) {
    expect(true).toBe(true);
    done();
  };

  describe('Plugin availability', function () {
    it("window.plugins.calendar should exist", function() {
      expect(window.plugins.calendar).toBeDefined();
    });
  });

  describe('API functions', function () {
    it("should define createEventWithOptions", function() {
      expect(window.plugins.calendar.createEventWithOptions).toBeDefined();
    });
  });
  
  describe('modifyEventWithOptions', function () {
    // if the reminders aren't readded to the editedItem they are removed.
    // For edited item must have the start and end dates specified.
    // Same notes too for some unexplainable reason!!
    // The modify function changes javascript null to a string
    // '<null>' for the notes variable only. :(
    var items =[{
              testWith:"With a repeating event, a middle event instance edited with spanFuture==false",
              testShould:"Should return a detached edited event and other instances unchanged.",
              calendarName:  'MyCreatedCalendar',
              title: 'My nice event',
              eventLocation: 'Home',
              notes: 'Some notes about this event.',
              startDate: new Date('December 17, 2016 03:24:00'),
              endDate: new Date('December 17, 2016 04:24:00'),
              firstReminderMinutes: 120,
              secondReminderMinutes: 5,
              recurrence: 'daily',
              recurrenceInterval: 2,
              recurrenceEndDate: new Date('December 21, 2016 04:24:00'),
              // This is the instance the user clicks on to edit.
              startDateInstance:new Date('December 19, 2016 03:24:00'),
              endDateInstance: new Date('December 19, 2016 04:24:00'),
              editedItem:{eventLocation:"Home",
                  firstReminderMinutes:5,
                  secondReminderMinutes:120,
                  startDate:new Date('December 19, 2016 03:24:00'),
                  endDate:new Date('December 19, 2016 04:24:00'),
                  recurrence:null,
                  title:'oh wow',
                  notes: 'Some notes about this event.',
                  calendarName:'MyCreatedCalendar',
                  recurrence: 'daily',
                  recurrenceInterval: 2,
                  recurrenceEndDate: new Date('December 21, 2016 04:24:00'),
                  spanFuture: false
                  },
              output:[{location:'Home',
                      alarms:{firstReminderMinutes:-5,secondReminderMinutes:-120},
                      endDate:'2016-12-19 04:24:00',startDate:'2016-12-19 03:24:00',
                      recurrences:[],title:'oh wow',message:'Some notes about this event.',calendar:'MyCreatedCalendar',isDetached:true},
                      {location:'Home',
                      endDate:'2016-12-17 04:24:00',startDate:'2016-12-17 03:24:00',
                      recurrences:[{endDate:'2016-12-21 04:24:00',interval:2,frequency:'daily'}],
                      title:'My nice event',
                      message:'Some notes about this event.',
                      calendar:'MyCreatedCalendar'},
                      {location:'Home',
                      endDate:'2016-12-21 04:24:00',startDate:'2016-12-21 03:24:00',
                      recurrences:[{endDate:'2016-12-21 04:24:00',interval:2,frequency:'daily'}],
                      title:'My nice event',
                      message:'Some notes about this event.',calendar:'MyCreatedCalendar'}]
              },
              {testWith:"With a recurring event, and a middle event edited with spanFuture==true",
              testShould:"Should return previous repeating events unchanged, and future events modified",
              calendarName:  'MyCreatedCalendar',
              title: 'cool event',
              eventLocation: 'Home',
              notes: 'Some notes about this event.',
              startDate: new Date('March 17, 2016 03:24:00'),
              endDate: new Date('March 17, 2016 04:24:00'),
              firstReminderMinutes: 120,
              secondReminderMinutes: 5,
              recurrence: 'daily',
              recurrenceInterval: 1,
              recurrenceEndDate: new Date('March 23, 2016 04:24:00'),
              // This is the instance the user clicks on to edit.
              startDateInstance: new Date('March 21, 2016 03:24:00'),
              endDateInstance: new Date('March 21, 2016 04:24:00'),
              editedItem:{eventLocation:"Home",
                  firstReminderMinutes:5,
                  secondReminderMinutes:120,
                  startDate:new Date('March 21, 2016 03:24:00'),
                  endDate:new Date('March 21, 2016 04:24:00'),
                  title:'so cool',
                  notes: 'Some notes about this event.',
                  calendarName:'MyCreatedCalendar',
                  recurrence: 'daily',
                  recurrenceInterval: 2,
                  recurrenceEndDate: new Date('March 24, 2016 04:24:00'),
                  spanFuture: true
                  },
              output:[
                    {"location":"Home",
                    "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                    "endDate":"2016-03-17 04:24:00","startDate":"2016-03-17 03:24:00",
                    "recurrences":[{"endDate":"2016-03-20 03:24:00","interval":1,"frequency":"daily"}],
                    "title":"cool event","message":"Some notes about this event.",
                    "calendar":"MyCreatedCalendar"},
                    {"location":"Home"
                    ,"alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                    "endDate":"2016-03-18 04:24:00","startDate":"2016-03-18 03:24:00",
                    "recurrences":[{"endDate":"2016-03-20 03:24:00","interval":1,"frequency":"daily"}],
                    "title":"cool event","message":"Some notes about this event.",
                    "calendar":"MyCreatedCalendar"},
                    {"location":"Home",
                    "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                    "endDate":"2016-03-19 04:24:00","startDate":"2016-03-19 03:24:00",
                    "recurrences":[{"endDate":"2016-03-20 03:24:00","interval":1,"frequency":"daily"}],
                    "title":"cool event","message":"Some notes about this event.",
                    "calendar":"MyCreatedCalendar"},
                    {"location":"Home",
                    "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                    "endDate":"2016-03-20 04:24:00","startDate":"2016-03-20 03:24:00",
                    "recurrences":[{"endDate":"2016-03-20 03:24:00","interval":1,"frequency":"daily"}],
                    "title":"cool event","message":"Some notes about this event.",
                    "calendar":"MyCreatedCalendar"},
                    {"location":"Home",
                    "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                    "endDate":"2016-03-21 04:24:00","startDate":"2016-03-21 03:24:00",
                    "recurrences":[{"endDate":"2016-03-24 04:24:00","interval":2,"frequency":"daily"}],
                    "title":"so cool","message":"Some notes about this event.",
                    "calendar":"MyCreatedCalendar"},
                    {"location":"Home",
                    "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                    "endDate":"2016-03-23 04:24:00","startDate":"2016-03-23 03:24:00",
                    "recurrences":[{"endDate":"2016-03-24 04:24:00","interval":2,"frequency":"daily"}],
                    "title":"so cool","message":"Some notes about this event.",
                    "calendar":"MyCreatedCalendar"}]
              },
              {testWith:"With very first recurrence edited with spanFuture == true",
              testShould:"Should return all events modified",
              calendarName:  'MyCreatedCalendar',
              title: 'this event',
              eventLocation: 'Home',
              notes: 'Some notes about this event.',
              startDate: new Date('March 17, 2016 03:24:00'),
              endDate: new Date('March 17, 2016 04:24:00'),
              firstReminderMinutes: 120,
              secondReminderMinutes: 5,
              recurrence: 'daily',
              recurrenceInterval: 2,
              recurrenceEndDate: new Date('March 21, 2016 04:24:00'),
              // This is the instance the user clicks on to edit.
              startDateInstance: new Date('March 17, 2016 03:24:00'),
              endDateInstance: new Date('March 17, 2016 04:24:00'),
              editedItem:{eventLocation:"Cool Place",
                  firstReminderMinutes:5,
                  secondReminderMinutes:120,
                  startDate:new Date('March 21, 2016 03:24:00'),
                  endDate:new Date('March 21, 2016 04:24:00'),
                  title:'so cool',
                  notes: 'Some notes about this event.',
                  calendarName:'MyCreatedCalendar',
                  recurrence: 'daily',
                  recurrenceInterval: 1,
                  recurrenceEndDate: new Date('March 23, 2016 04:24:00'),
                  spanFuture: true
                  },
              output:[{"location":"Cool Place",
                "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                "endDate":"2016-03-21 04:24:00","startDate":"2016-03-21 03:24:00",
                "recurrences":[{"endDate":"2016-03-23 04:24:00","interval":1,"frequency":"daily"}],
                "title":"so cool","message":"Some notes about this event.",
                "calendar":"MyCreatedCalendar"},
                {"location":"Cool Place",
                "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                "endDate":"2016-03-22 04:24:00","startDate":"2016-03-22 03:24:00",
                "recurrences":[{"endDate":"2016-03-23 04:24:00","interval":1,"frequency":"daily"}],
                "title":"so cool","message":"Some notes about this event.",
                "calendar":"MyCreatedCalendar"},
                {"location":"Cool Place",
                "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                "endDate":"2016-03-23 04:24:00","startDate":"2016-03-23 03:24:00",
                "recurrences":[{"endDate":"2016-03-23 04:24:00","interval":1,"frequency":"daily"}],
                "title":"so cool","message":"Some notes about this event.",
                "calendar":"MyCreatedCalendar"}],
              },
                {testWith:"With nonrecurring (and non detached item) edited to be recurring with spanFuture==true",
                  testShould:"Should return recurring event",
                  calendarName:  'MyCreatedCalendar',
                  title: 'this event',
                  eventLocation: 'Home',
                  notes: 'Some notes about this event.',
                  startDate: new Date('March 11, 2016 03:24:00'),
                  endDate: new Date('March 11, 2016 04:24:00'),
                  firstReminderMinutes: 120,
                  secondReminderMinutes: 5,
                  /*recurrence: 'daily',
                  recurrenceInterval: 2,
                  recurrenceEndDate: new Date('March 21, 2016 04:24:00'),*/
                  // This is the instance the user clicks on to edit.
                  startDateInstance: new Date('March 11, 2016 03:24:00'),
                  endDateInstance: new Date('March 11, 2016 04:24:00'),
                  editedItem:{eventLocation:"Cool Place",
                      firstReminderMinutes:5,
                      secondReminderMinutes:120,
                      startDate:new Date('March 11, 2016 03:24:00'),
                      endDate:new Date('March 11, 2016 04:24:00'),
                      title:'so cool',
                      notes: 'Some other notes.',
                      calendarName:'MyCreatedCalendar',
                      recurrence: 'daily',
                      recurrenceInterval: 1,
                      recurrenceEndDate: new Date('March 12, 2016 04:24:00'),
                      spanFuture: true
                      },
                  output:[{"location":"Cool Place",
                  "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                  "endDate":"2016-03-11 04:24:00","startDate":"2016-03-11 03:24:00",
                  "recurrences":[{"endDate":"2016-03-12 04:24:00","interval":1,"frequency":"daily"}],
                  "title":"so cool","message":"Some other notes.",
                  "calendar":"MyCreatedCalendar"},
                  {"location":"Cool Place",
                  "alarms":{"firstReminderMinutes":-5,"secondReminderMinutes":-120},
                  "endDate":"2016-03-12 04:24:00","startDate":"2016-03-12 03:24:00",
                  "recurrences":[{"endDate":"2016-03-12 04:24:00","interval":1,"frequency":"daily"}],
                  "title":"so cool","message":"Some other notes.",
                  "calendar":"MyCreatedCalendar"}]
              }
              ];
    function findEventCheckValues (item, itemIndex){
        describe(item.testWith, function(){
        var success = function(message) { console.log("Success: " + JSON.stringify(message)); },
        error = function(message) { 
          console.log("Error: " + message);
        },

        calOptions = window.plugins.calendar.getCalendarOptions(); 
        calOptions.firstReminderMinutes = item.firstReminderMinutes;
        calOptions.secondReminderMinutes = item.secondReminderMinutes;
        if(item.recurrence){
          calOptions.recurrence = item.recurrence;
          calOptions.recurrenceInterval = item.recurrenceInterval; 
          calOptions.recurrenceEndDate = item.recurrenceEndDate;
        }
        calOptions.calendarName = item.calendarName;

        beforeEach(function(done) {
          var success = function(result) { 
              //console.log(result);
              calOptions.id = result;
              done();
          },
          successList = function(result){
            var foundCal = false;
            for(var i = 0; i<result.length;i++){
              if (result[i].name === item.calendarName){
                foundCal = true;
              }
            }
            if(foundCal){
              window.plugins.calendar.deleteCalendar(item.calendarName,deleteFinish,error);
            }else{
              window.plugins.calendar.createEventWithOptions(item.title,item.eventLocation,
                item.notes,item.startDate,item.endDate,calOptions,success,error);
            }
          },
          deleteFinish = function(result){
            window.plugins.calendar.createEventWithOptions(item.title,item.eventLocation,
                item.notes,item.startDate,item.endDate,calOptions,success,error);
          };
          window.plugins.calendar.listCalendars(successList,error);
        });
        it(item.testShould+" for input "+itemIndex.toString(), function(done) {

          var success = function(result) { 
            window.plugins.calendar.findAllEventsInNamedCalendar(item.editedItem.calendarName,
                  successFind,error);
          };
          var successFind = function(result){
            for(var i =0; i<result.length;i++){
              
              delete result[i].id;
            }
            expect(item.output).toEqual(result);
            console.log(result);
            done();
            

          };
          var newCalOptions = window.plugins.calendar.getCalendarOptions();
          newCalOptions.firstReminderMinutes = item.editedItem.firstReminderMinutes;
          newCalOptions.secondReminderMinutes = item.editedItem.secondReminderMinutes;
          newCalOptions.calendarName = item.editedItem.calendarName;
          newCalOptions.recurrence = item.editedItem.recurrence;
          newCalOptions.recurrenceInterval = item.editedItem.recurrenceInterval; 
          newCalOptions.recurrenceEndDate = item.editedItem.recurrenceEndDate;
          window.plugins.calendar.modifyEventWithOptions(item.title, item.eventLocation, item.notes, 
            item.startDateInstance, item.endDateInstance, item.editedItem.title, item.editedItem.eventLocation, item.editedItem.notes, 
            item.editedItem.startDate, item.editedItem.endDate,
            item.editedItem.spanFuture ,calOptions, newCalOptions, success, error);
        });

      });
    }//end function
    //findEventCheckValues(items[0], 0)
    for(var i=0; i<items.length;i++){
      findEventCheckValues(items[i], i);
    }
    
  });

  

  /*
  TODO extend - this is a copy-paste example of Toast
  describe('Invalid usage', function () {
    it("should fail due to an invalid position", function(done) {
     window.plugins.toast.show('hi', 'short', 'nowhere', fail.bind(null, done), succeed.bind(null, done));
    });

    it("should fail due to an invalid duration", function(done) {
     window.plugins.toast.show('hi', 'medium', 'top', fail.bind(null, done), succeed.bind(null, done));
    });
  });
  */
};