require 'icalendar'

class Webcal < ActiveRecord::Base
  belongs_to :user

  #
  # Generates a single `Icalendar::Calendar` object from this `Webcal` including calendar events for the specified
  # collection of `TaskDefinition`s.
  #
  # The `unit` property of each `TaskDefinition` is accessed; ensure it is included to prevent N+1 selects. For example,
  #
  #   to_ical_with_task_definitions(
  #     TaskDefinition
  #       .joins(:unit)
  #       .includes(:unit)
  #   )
  #
  def to_ical_with_task_definitions(defs = [])
    ical = Icalendar::Calendar.new
    ical.prodid = Doubtfire::Application.config.institution[:product_name]

    # Add iCalendar events for the specified definition.
    defs.each do |td|
      # Notes:
      # - Start and end dates of events are equal because the calendar event is expected to be an "all-day" event.
      # - iCalendar clients identify events across syncs by their UID property, which is currently the task definition
      #   ID prefixed with S- or E- based on whether it is a start or end event.

      ev_name = "#{td.unit.code}: #{td.abbreviation}: #{td.name}"
      ev_date_format = '%Y%m%d'

      # Add event for start date, if the user opted in.
      if include_start_dates
        ical.event do |ev|
          ev.uid = "S-#{td.id}"
          ev.summary = "Start: #{ev_name}"
          ev.dtstart = ev.dtend = Icalendar::Values::Date.new(td.start_date.strftime(ev_date_format))
        end
      end

      # Add event for target/extended date.
      ical.event do |ev|
        ev.uid = "E-#{td.id}"
        ev.summary = "#{include_start_dates ? 'End:' : ''}#{ev_name}"

        ev_date = td.target_date
        ev_date += (td.tasks.first.extensions * 7).day if td.tasks.present?
        ev.dtstart = ev.dtend = Icalendar::Values::Date.new(ev_date.strftime(ev_date_format))
      end
    end

    ical
  end
end
