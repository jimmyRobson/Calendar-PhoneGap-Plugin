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
    var items =[{calendarName:  'MyCreatedCalendar',
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
              editedItem:{location:"",
                  firstReminderMinutes:5,
                  secondReminderMinutes:120,
                  startDate:new Date('December 17, 2016 03:24:00'),
                  endDate:new Date('December 17, 2016 04:24:00'),
                  recurrence:null,
                  title:'oh wow',
                  notes: 'Some notes about this event.',
                  calendarName:'MyCreatedCalendar',
                  recurrence: 'daily',
                  recurrenceInterval: 2,
                  recurrenceEndDate: new Date('December 21, 2016 04:24:00'),
                  },
              output:[{location:'Home',
                  alarms:{firstReminderMinutes:-5,
                            secondReminderMinutes:-120},
                  endDate:'2016-12-17 04:24:00',
                  startDate:'2016-12-17 03:24:00',
                  recurrences:[{endDate:'2016-12-21 04:24:00',
                                interval:2,frequency:'daily'}],
                  title:'oh wow',
                  message:'Some notes about this event.',
                  calendar:'MyCreatedCalendar',
                  isDetached:true
                  }]
              }];
    function findEventCheckValues (item){
      var id,
      success = function(message) { console.log("Success: " + JSON.stringify(message)); },
      error = function(message) { console.log("Error: " + message); };

      var calOptions = window.plugins.calendar.getCalendarOptions(); // grab the defaults
      calOptions.firstReminderMinutes = item.firstReminderMinutes;
      calOptions.secondReminderMinutes = item.secondReminderMinutes;

      calOptions.recurrence = item.recurrence;
      calOptions.recurrenceInterval = item.recurrenceInterval; 
      calOptions.recurrenceEndDate = item.recurrenceEndDate;
      calOptions.calendarName = item.calendarName;

      beforeEach(function(done) {
        var success = function(result) { 
          id=result;
          calOptions.id = result;
          item.id = result; // Should have same id as one created.
          done();
        };
          window.plugins.calendar.createEventWithOptions(item.title,item.eventLocation,
            item.notes,item.startDate,item.endDate,calOptions,success,error);
      });
      it("modify the correct results", function(done) {

        var success = function(result) { 
          newCalOptions.id = result;
          item.output[0].id = result;
          /*window.plugins.calendar.findEventWithOptions(item.editedItem.title,item.editedItem.eventLocation,
            item.editedItem.notes,item.editedItem.startDate, item.editedItem.endDate,
            calOptions,successFind,error);*/
          //This only looks up by newCalOptions.id , all other values don't matter.
          window.plugins.calendar.findEventWithOptions(null,null,
            null,new Date(null), new Date(null),
            newCalOptions,successFind,error);
        };
        var successFind = function(result){
          console.log(result);
          console.log(item.output);
          expect(result).toBeDefined();
          expect(result).toEqual(item.output);
          done();
        }
        var error = function(result) { 
          console.log('error');
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
          item.startDate, item.endDate, item.editedItem.title, item.editedItem.eventLocation, item.editedItem.notes, 
          item.editedItem.startDate, item.editedItem.endDate,calOptions, newCalOptions, success, error);
      });


    }//end function
    /*var calendarName = 'MyCreatedCalendar';
    success = function(message) { 

      console.log("Success: " + JSON.stringify(message)); },
    error = function(message) { console.log("Error: " + message); };
    window.plugins.calendar.deleteCalendar(calendarName,success,error);*/
    for(var i = 0; i < items.length; i++) {
      findEventCheckValues(items[0]);
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
