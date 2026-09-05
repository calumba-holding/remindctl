import Foundation
import Testing

@testable import RemindCore

@MainActor
struct ReminderFilteringTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }()

  private func reminders(now: Date) -> [ReminderItem] {
    let today = calendar.startOfDay(for: now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
    return [
      ReminderItem(
        id: "1",
        title: "Overdue",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: yesterday,
        listID: "a",
        listName: "Home"
      ),
      ReminderItem(
        id: "2",
        title: "Today",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: today,
        listID: "a",
        listName: "Home"
      ),
      ReminderItem(
        id: "3",
        title: "Tomorrow",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: tomorrow,
        listID: "a",
        listName: "Home"
      ),
      ReminderItem(
        id: "5",
        title: "No Due",
        notes: nil,
        isCompleted: false,
        completionDate: nil,
        priority: .none,
        dueDate: nil,
        listID: "a",
        listName: "Home"
      ),
      ReminderItem(
        id: "4",
        title: "Completed",
        notes: nil,
        isCompleted: true,
        completionDate: now,
        priority: .none,
        dueDate: today,
        listID: "a",
        listName: "Home"
      ),
    ]
  }

  @Test("Today filter includes overdue")
  func todayIncludesOverdue() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .today, now: now, calendar: calendar)
    #expect(result.count == 2)
  }

  @Test("Tomorrow filter")
  func tomorrowFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .tomorrow, now: now, calendar: calendar)
    #expect(result.count == 1)
    #expect(result.first?.title == "Tomorrow")
  }

  @Test("Overdue filter")
  func overdueFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .overdue, now: now, calendar: calendar)
    #expect(result.count == 1)
    #expect(result.first?.title == "Overdue")
  }

  @Test("Upcoming filter ignores no due date")
  func upcomingFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .upcoming, now: now, calendar: calendar)
    #expect(result.count == 3)
  }

  @Test("Open filter includes no due date and excludes completed")
  func openFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .open, now: now, calendar: calendar)
    #expect(result.count == 4)
    #expect(result.contains(where: { $0.title == "No Due" }))
    #expect(result.allSatisfy { !$0.isCompleted })
  }

  @Test("Date filter")
  func dateFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let today = calendar.startOfDay(for: now)
    let result = ReminderFiltering.apply(items, filter: .date(today), now: now, calendar: calendar)
    #expect(result.count == 1)
    #expect(result.first?.title == "Today")
  }

  @Test("All filter includes completed")
  func allFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .all, now: now, calendar: calendar)
    #expect(result.count == items.count)
  }

  @Test("Sort orders by due date then title")
  func sortOrder() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let sorted = ReminderFiltering.sort(items)
    #expect(sorted.first?.title == "Overdue")
    #expect(sorted.last?.title == "No Due")
  }

  @Test("Completed filter")
  func completedFilter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let items = reminders(now: now)
    let result = ReminderFiltering.apply(items, filter: .completed, now: now, calendar: calendar)
    #expect(result.count == 1)
    #expect(result.first?.title == "Completed")
  }

  @Test("Week filter excludes a date-only due on next week's first instant")
  func weekFilterExcludesNextWeekStart() {
    var weekCalendar = Calendar(identifier: .gregorian)
    weekCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    weekCalendar.locale = Locale(identifier: "en_US_POSIX")
    weekCalendar.firstWeekday = 1

    // Wednesday 2023-11-15 12:00 UTC. Sunday-start week is [2023-11-12, 2023-11-19).
    let now = Date(timeIntervalSince1970: 1_700_049_600)
    let interval = weekCalendar.dateInterval(of: .weekOfYear, for: now)
    #expect(interval != nil)
    let start = interval?.start ?? now
    let end = interval?.end ?? now

    let thisWeekStart = ReminderItem(
      id: "week-start",
      title: "ThisWeekStart",
      notes: nil,
      isCompleted: false,
      completionDate: nil,
      priority: .none,
      dueDate: start,
      dueDateIsAllDay: true,
      listID: "a",
      listName: "Home"
    )
    let lastInstantThisWeek = ReminderItem(
      id: "week-last",
      title: "LastInstantThisWeek",
      notes: nil,
      isCompleted: false,
      completionDate: nil,
      priority: .none,
      dueDate: end.addingTimeInterval(-1),
      listID: "a",
      listName: "Home"
    )
    let nextWeekStart = ReminderItem(
      id: "next-week",
      title: "NextWeekStart",
      notes: nil,
      isCompleted: false,
      completionDate: nil,
      priority: .none,
      dueDate: end,
      dueDateIsAllDay: true,
      listID: "a",
      listName: "Home"
    )

    let result = ReminderFiltering.apply(
      [thisWeekStart, lastInstantThisWeek, nextWeekStart],
      filter: .week,
      now: now,
      calendar: weekCalendar
    )
    let titles = Set(result.map(\.title))
    #expect(titles.contains("ThisWeekStart"))
    #expect(titles.contains("LastInstantThisWeek"))
    #expect(!titles.contains("NextWeekStart"))
  }
}
