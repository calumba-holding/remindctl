import Foundation
import Testing

@testable import RemindCore
@testable import remindctl

@MainActor
struct ListCommandTests {
  @Test("Multiple list names are allowed for read-only listing")
  func multipleNamesAllowedForListing() throws {
    let name = try ListCommand.singleListName(["Work", "Home"], forMutation: false)
    #expect(name == "Work")
  }

  @Test("Multiple list names are rejected for mutations")
  func multipleNamesRejectedForMutations() {
    #expect(throws: Error.self) {
      _ = try ListCommand.singleListName(["Work", "Home"], forMutation: true)
    }
  }

  @Test("Multiple list names keep read-only multi-list behavior")
  func multipleNamesUseMultiListReadOnlyPath() {
    #expect(ListCommand.shouldReadMultipleLists(names: ["Work", "Home"], listID: nil, isMutation: false))
    #expect(!ListCommand.shouldReadMultipleLists(names: ["Work", "Home"], listID: nil, isMutation: true))
    #expect(!ListCommand.shouldReadMultipleLists(names: ["Work", "Home"], listID: "LIST", isMutation: false))
  }

  @Test("Open command keeps list-constrained filter behavior")
  func openListWithoutAppShowsOpenReminders() {
    #expect(OpenCommand.shouldShowOpenReminders(id: nil, listName: "Work", listID: nil, app: false))
    #expect(OpenCommand.shouldShowOpenReminders(id: nil, listName: nil, listID: "LIST", app: false))
    #expect(!OpenCommand.shouldShowOpenReminders(id: nil, listName: "Work", listID: nil, app: true))
    #expect(!OpenCommand.shouldShowOpenReminders(id: "A123", listName: nil, listID: nil, app: false))
  }

  @Test("Create plans a new list when no matching list exists")
  func createPlansNewListWhenMissing() throws {
    let lists = [
      ReminderList(id: "AAAA-1111", title: "Work")
    ]
    #expect(try ListCommand.existingListForCreate(name: "Projects", lists: lists) == nil)
  }

  @Test("Create reuses a unique existing list instead of inserting another")
  func createReusesUniqueExistingList() throws {
    let existing = ReminderList(id: "AAAA-1111", title: "Projects")
    #expect(try ListCommand.existingListForCreate(name: "Projects", lists: [existing]) == existing)
  }

  @Test("Create reuses a unique case-insensitive match")
  func createReusesCaseInsensitiveMatch() throws {
    let existing = ReminderList(id: "AAAA-1111", title: "Projects")
    #expect(try ListCommand.existingListForCreate(name: "projects", lists: [existing]) == existing)
  }

  @Test("Create reuses a unique normalized list name")
  func createReusesNormalizedMatch() throws {
    let existing = ReminderList(id: "AAAA-1111", title: "📋 Projects!")
    #expect(try ListCommand.existingListForCreate(name: "projects", lists: [existing]) == existing)
  }

  @Test("Reused list summaries count open and overdue reminders by list ID")
  func reusedListCounts() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let now = Date(timeIntervalSince1970: 1_700_049_600)
    let today = calendar.startOfDay(for: now)
    let cases: [(id: String, listID: String, completed: Bool, due: Date?)] = [
      ("overdue", "A", false, today.addingTimeInterval(-1)),
      ("today", "A", false, today),
      ("future", "A", false, today.addingTimeInterval(86_400)),
      ("undated", "A", false, nil),
      ("completed", "A", true, today.addingTimeInterval(-1)),
      ("other-list", "B", false, today.addingTimeInterval(-1)),
    ]
    let reminders = cases.map { item in
      ReminderItem(
        id: item.id,
        title: item.id,
        notes: nil,
        isCompleted: item.completed,
        completionDate: nil,
        priority: .none,
        dueDate: item.due,
        listID: item.listID,
        listName: "Projects"
      )
    }
    let summaries = ListCommand.summaries(
      for: [ReminderList(id: "A", title: "Projects"), ReminderList(id: "empty", title: "Empty")],
      reminders: reminders,
      now: now,
      calendar: calendar
    )
    #expect(summaries.count == 2)
    #expect(summaries[0].id == "A")
    #expect(summaries[0].reminderCount == 4)
    #expect(summaries[0].overdueCount == 1)
    #expect(summaries[1].reminderCount == 0)
    #expect(summaries[1].overdueCount == 0)
  }

  @Test("Create rejects an already-ambiguous list name")
  func createRejectsAmbiguousExistingName() {
    let lists = [
      ReminderList(id: "AAAA-1111", title: "Projects"),
      ReminderList(id: "BBBB-2222", title: "Projects"),
    ]
    #expect(throws: RemindCoreError.self) {
      _ = try ListCommand.existingListForCreate(name: "Projects", lists: lists)
    }
  }
}
