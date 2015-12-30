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
  
  describe('findEventWithOptions', function () {
    
    var inputs =[{calendarName:  "MyCreatedCalendar",
              title: "My nice event",
              eventLocation: "Home",
              notes: "Some notes about this event.",
              startDate: new Date('December 17, 2016 03:24:00'),
              endDate: new Date('December 17, 2016 04:24:00'),
              firstReminderMinutes: 120,
              secondReminderMinutes: 5,
              recurrence: "daily",
              recurrenceInterval: 2,
              recurrenceEndDate: new Date('December 21, 2016 04:24:00')
              }],
    outputs = [
                [{"location":"Home",
                  "alarms":{"firstReminderMinutes":-5,
                            "secondReminderMinutes":-120},
                  "endDate":"2016-12-17 04:24:00",
                  "startDate":"2016-12-17 03:24:00",
                  "recurrences":[{"endDate":"2016-12-21 04:24:00",
                                "interval":2,"frequency":"daily"}],
                  "title":"My nice event",
                  "message":"Some notes about this event.",
                  "calendar":"MyCreatedCalendar"
                  }]
              ];
    function findEventCheckValues (input, output){
      var id,
      success = function(message) { console.log("Success: " + JSON.stringify(message)); },
      error = function(message) { console.log("Error: " + message); };

      var calOptions = window.plugins.calendar.getCalendarOptions(); // grab the defaults
      calOptions.firstReminderMinutes = input.firstReminderMinutes;
      calOptions.secondReminderMinutes = input.secondReminderMinutes;

      calOptions.recurrence = input.recurrence;
      calOptions.recurrenceInterval = input.recurrenceInterval; 
      calOptions.recurrenceEndDate = input.recurrenceEndDate;
      calOptions.calendarName = input.calendarName;

      beforeEach(function(done) {
        var success = function(result) { 
          console.log(result);
          id=result;
          output[0].id = result; // Should have same id as one created.
          done();
        };
        window.plugins.calendar.createEventWithOptions(input.title,input.eventLocation,
            input.notes,input.startDate,input.endDate,calOptions,success,error);
      });
    
      it("should return correct results", function(done) {
        var calOptions = window.plugins.calendar.getCalendarOptions();
        calOptions.calendarName = input.calendarName;
        calOptions.id = id;// Look up by event ID
        var success = function(result) { 
          console.log(result);
          expect(result).toBeDefined();
          expect(result).toEqual(output);
          console.log(output);

          done();
        };
        window.plugins.calendar.findEventWithOptions(null,null,null,new Date(null),
            new Date(null),calOptions,success,error);
      });

    }
    for(var i = 0; i < inputs.length; i++) {
      findEventCheckValues(inputs[i], outputs[i]);
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
