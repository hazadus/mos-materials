import Cocoa

extension String {
  /// String extension to decode HTML entities.
  var decoded: String {
    let attr = try? NSAttributedString(
      data: Data(utf8),
      options: [
        .documentType: NSAttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue
      ],
      documentAttributes: nil)

    return attr?.string ?? self
  }
}

enum FetchError: Error {
  case badURL
  case badResponse
  case badJSON
}

func getDataForDay(month: Int, day: Int) async throws {
  let address = "https://today.zenquotes.io/api/\(month)/\(day)"
  guard let url = URL(string: address) else {
    throw FetchError.badURL
  }
  let request = URLRequest(url: url)

  let (data, response) = try await URLSession.shared.data(for: request)
  guard
    let response = response as? HTTPURLResponse,
    response.statusCode < 400 else {
      throw FetchError.badResponse
    }

  if let jsonString = String(data: data, encoding: .utf8) {
    saveSampleData(json: jsonString)
  }
}

//Task {
//  do {
//    try await getDataForDay(month: 2, day: 8)
//  } catch {
//    print(error)
//  }
//}


struct EventLink: Decodable, Identifiable {
    let id: UUID // назначает "вручную" при создании инстанса
    let title: String
    let url: URL
}

struct Event: Decodable, Identifiable {
    let id: UUID = UUID() // инициализируем тут, и не указываем в CodingKeys
    let year: String
    
    // Поля из JSON
    let text: String
    let links: [EventLink]
    
    enum CodingKeys: String, CodingKey {
        case text
        case links
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        // Получаем год и описание из поля text
        let rawText = try values.decode(String.self, forKey: .text)
        let textParts = rawText.components(separatedBy: " &#8211; ")
        
        if textParts.count == 2 {
            year = textParts[0]
            text = textParts[1].decoded
        } else {
            year = "?"
            text = rawText.decoded
        }
        
        let allLinks = try values.decode(
            [String: [String: String]].self,
            forKey: .links
        )
        
        var processedLinks: [EventLink] = []
        for (_, link) in allLinks {
            if let title = link["2"],
               let address = link["1"],
               let url = URL(string: address) {
                processedLinks.append(
                    EventLink(id: UUID(), title: title, url: url)
                )
            }
        }
        links = processedLinks
    }
}

enum EventType: String {
    case events = "Events"
    case births = "Births"
    case deaths = "Deaths"
}

struct Day: Decodable {
    let date: String
    let data: [String: [Event]]
    
    var events: [Event] { data[EventType.events.rawValue] ?? [] }
    var births: [Event] { data[EventType.births.rawValue] ?? [] }
    var deaths: [Event] { data[EventType.deaths.rawValue] ?? [] }
    
    var displayDate: String {
        date.replacingOccurrences(of: "_", with: " ")
    }
}

if let data = readSampleData() {
    do {
        let day = try JSONDecoder().decode(Day.self, from: data)
        print("Date: " + day.displayDate)
        print("Births qty: \(day.births.count)")
        print(day.births[0].text)
        print(day.births[0].year)
    } catch {
        print(error)
    }
}
