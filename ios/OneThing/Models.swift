import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var done: Bool

    init(id: String = UUID().uuidString, text: String = "", done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }
}

struct NiceItem: Codable, Equatable {
    var text: String
    var done: Bool

    init(text: String = "", done: Bool = false) {
        self.text = text
        self.done = done
    }

    init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            self.text = text
            self.done = false
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        done = try container.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }
}

struct DailyPlan: Codable, Equatable {
    var goal: String
    var goalCompleted: Bool
    var niceToDo: [NiceItem]
    var hygieneLeft: [String]
    var hygieneRight: [String]

    init(
        goal: String = "",
        goalCompleted: Bool = false,
        niceToDo: [NiceItem] = [],
        hygieneLeft: [String] = [],
        hygieneRight: [String] = []
    ) {
        self.goal = goal
        self.goalCompleted = goalCompleted
        self.niceToDo = niceToDo
        self.hygieneLeft = hygieneLeft
        self.hygieneRight = hygieneRight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        goalCompleted = try container.decodeIfPresent(Bool.self, forKey: .goalCompleted) ?? false
        niceToDo = try container.decodeIfPresent([NiceItem].self, forKey: .niceToDo) ?? []
        hygieneLeft = try container.decodeIfPresent([String].self, forKey: .hygieneLeft) ?? []
        hygieneRight = try container.decodeIfPresent([String].self, forKey: .hygieneRight) ?? []
    }
}

struct WeekGoal: Codable, Equatable {
    var goal: String
    var goalCompleted: Bool

    init(goal: String = "", goalCompleted: Bool = false) {
        self.goal = goal
        self.goalCompleted = goalCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goal = try container.decodeIfPresent(String.self, forKey: .goal) ?? ""
        goalCompleted = try container.decodeIfPresent(Bool.self, forKey: .goalCompleted) ?? false
    }
}

struct HLC: Codable, Equatable, Comparable {
    var physical: Int64
    var logical: Int
    var device: String

    static func < (lhs: HLC, rhs: HLC) -> Bool {
        if lhs.physical != rhs.physical { return lhs.physical < rhs.physical }
        if lhs.logical != rhs.logical { return lhs.logical < rhs.logical }
        return lhs.device < rhs.device
    }
}

struct SyncOp: Codable, Equatable, Identifiable {
    var opId: String
    var recordType: String
    var recordId: String
    var fields: JSONValue
    var deleted: Bool
    var hlc: HLC

    var id: String { opId }
}

struct SyncRecord: Codable, Equatable {
    var recordType: String
    var recordId: String
    var fields: JSONValue
    var deleted: Bool
    var hlc: HLC
    var serverSeq: Int64
}
