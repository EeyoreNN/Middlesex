import Foundation
import UIKit
import CloudKit

class OpenAIVisionAPI {
    static let shared = OpenAIVisionAPI()

    private let apiKeyKey = "OPENAI_API_KEY"
    private var cachedAPIKey: String?

    private init() {}

    private func getAPIKey() async throws -> String {
        print("🔑 [OpenAI] Starting API key lookup...")

        // Return cached key if available
        if let cached = cachedAPIKey {
            print("🔑 [OpenAI] Using cached API key")
            return cached
        }

        // Try to fetch from CloudKit
        print("🔑 [OpenAI] Attempting to fetch API key from CloudKit...")
        if let cloudKey = try? await fetchAPIKeyFromCloudKit() {
            print("🔑 [OpenAI] ✅ Found API key in CloudKit")
            cachedAPIKey = cloudKey
            return cloudKey
        }
        print("🔑 [OpenAI] ⚠️ No API key found in CloudKit")

        // Fallback to local UserDefaults
        print("🔑 [OpenAI] Checking UserDefaults...")
        if let key = UserDefaults.standard.string(forKey: apiKeyKey), !key.isEmpty {
            print("🔑 [OpenAI] ✅ Found API key in UserDefaults")
            return key
        }
        print("🔑 [OpenAI] ⚠️ No API key in UserDefaults")

        // Fallback to Info.plist
        print("🔑 [OpenAI] Checking Info.plist...")
        if let key = Bundle.main.object(forInfoDictionaryKey: apiKeyKey) as? String {
            print("🔑 [OpenAI] ✅ Found API key in Info.plist")
            return key
        }
        print("🔑 [OpenAI] ⚠️ No API key in Info.plist")

        print("🔑 [OpenAI] ❌ API key not found in any location")
        throw ScheduleProcessingError.apiKeyNotFound
    }

    private func fetchAPIKeyFromCloudKit() async throws -> String? {
        print("🔑 [CloudKit] Querying AppSettings for openai_api_key...")
        let database = CKContainer.default().publicCloudDatabase
        let predicate = NSPredicate(format: "settingKey == %@", "openai_api_key")
        let query = CKQuery(recordType: "AppSettings", predicate: predicate)

        do {
            let results = try await database.records(matching: query)
            print("🔑 [CloudKit] Query returned \(results.matchResults.count) results")

            if let record = try results.matchResults.first?.1.get() {
                let value = record["settingValue"] as? String
                print("🔑 [CloudKit] Found API key: \(value != nil ? "Yes (length: \(value?.count ?? 0))" : "No")")
                return value
            }

            print("🔑 [CloudKit] No matching record found")
            return nil
        } catch {
            print("🔑 [CloudKit] ❌ Error fetching from CloudKit: \(error)")
            throw error
        }
    }

    func saveAPIKeyToCloudKit(_ key: String) async throws {
        let database = CKContainer.default().publicCloudDatabase

        // Check if setting already exists
        let predicate = NSPredicate(format: "settingKey == %@", "openai_api_key")
        let query = CKQuery(recordType: "AppSettings", predicate: predicate)

        let results = try await database.records(matching: query)
        let record: CKRecord

        if let existingRecord = try results.matchResults.first?.1.get() {
            record = existingRecord
        } else {
            record = CKRecord(recordType: "AppSettings")
            record["id"] = UUID().uuidString as CKRecordValue
            record["settingKey"] = "openai_api_key" as CKRecordValue
        }

        record["settingValue"] = key as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        try await database.save(record)
        cachedAPIKey = key
    }

    func setAPIKey(_ key: String) {
        print("🔑 [OpenAI] Setting API key...")
        // Save to UserDefaults as fallback
        UserDefaults.standard.set(key, forKey: apiKeyKey)

        // Save to CloudKit asynchronously
        Task {
            do {
                try await saveAPIKeyToCloudKit(key)
                print("🔑 [OpenAI] ✅ API key saved to CloudKit")
            } catch {
                print("🔑 [OpenAI] ❌ Failed to save to CloudKit: \(error)")
            }
        }
    }

    // Test function using simple GPT-3.5 model
    func testAPIKey() async throws -> String {
        print("🧪 [OpenAI] Starting API key test...")
        let apiKey = try await getAPIKey()
        print("🧪 [OpenAI] API key retrieved, making test request...")

        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "user",
                    "content": "Say 'API key is working!' in 5 words or less."
                ]
            ],
            "max_tokens": 20
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw ScheduleProcessingError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("🧪 [OpenAI] Sending request to OpenAI...")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScheduleProcessingError.invalidResponse
        }

        print("🧪 [OpenAI] Response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "unknown error"
            print("🧪 [OpenAI] ❌ Error response: \(errorString)")
            throw ScheduleProcessingError.invalidResponse
        }

        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let content = apiResponse.choices.first?.message.content ?? "No response"

        print("🧪 [OpenAI] ✅ Test successful! Response: \(content)")
        return content
    }

    func parseSchedule(imageData: Data, weekType: String) async throws -> [String: [BlockTime]] {
        let apiKey = try await getAPIKey()

        let base64Image = imageData.base64EncodedString()

        let prompt = """
        You are analyzing a school schedule image for \(weekType) Week at Middlesex School.

        Extract the following information for EACH day of the week (Monday through Friday):
        - All class blocks (A, B, C, D, E, F, G) with their start and end times
        - Any X blocks (extended blocks) with their start and end times
        - Morning Meeting or Assembly times if present
        - Lunch block times

        IMPORTANT NOTES:
        - X blocks are extended class periods that vary by day
        - Some days may have X blocks, some may not
        - Times should be in 24-hour format (e.g., 08:00, 13:30)
        - Block names should be single letters (A, B, C, D, E, F, G) or "X" for extended blocks
        - Include "Morning Meeting", "Assembly", or "Lunch" as block names when present

        Return a JSON object with this exact structure:
        {
          "Monday": [
            {"block": "A", "startTime": "08:00", "endTime": "08:50"},
            {"block": "X", "startTime": "08:55", "endTime": "10:25"},
            ...
          ],
          "Tuesday": [...],
          "Wednesday": [...],
          "Thursday": [...],
          "Friday": [...]
        }

        Return ONLY the JSON object, no other text.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 2000
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw ScheduleProcessingError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("OpenAI API Error Response: \(String(data: data, encoding: .utf8) ?? "unknown")")
            throw ScheduleProcessingError.invalidResponse
        }

        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let content = apiResponse.choices.first?.message.content else {
            throw ScheduleProcessingError.invalidResponse
        }

        // Parse the JSON response
        let schedule = try parseScheduleJSON(content)
        return schedule
    }

    private func parseScheduleJSON(_ jsonString: String) throws -> [String: [BlockTime]] {
        // Clean the response - remove markdown code blocks if present
        var cleanJSON = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanJSON.hasPrefix("```json") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "```json", with: "")
        }
        if cleanJSON.hasPrefix("```") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "```", with: "")
        }
        if cleanJSON.hasSuffix("```") {
            cleanJSON = String(cleanJSON.dropLast(3))
        }
        cleanJSON = cleanJSON.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanJSON.data(using: .utf8) else {
            throw ScheduleProcessingError.invalidResponse
        }

        let scheduleData = try JSONDecoder().decode([String: [BlockTimeData]].self, from: jsonData)

        // Convert BlockTimeData to BlockTime
        var schedule: [String: [BlockTime]] = [:]
        for (day, blocks) in scheduleData {
            schedule[day] = blocks.map { BlockTime(block: $0.block, startTime: $0.startTime, endTime: $0.endTime) }
        }

        return schedule
    }
}

// MARK: - API Response Models

struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}
