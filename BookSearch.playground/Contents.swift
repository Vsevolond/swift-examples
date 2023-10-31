import Combine
import PlaygroundSupport
import SwiftUI
import UIKit
 
struct Book: Codable, Identifiable {
  let id, title, author: String
 
  init(from openLibraryBook: BookSearchResultBook) {
    self.id = openLibraryBook.key ?? UUID().uuidString
    self.title = openLibraryBook.title ?? ""
    self.author = openLibraryBook.authorName?[0] ?? ""
  }
}
 
struct BookSearchResult: Codable {
  let books: [BookSearchResultBook]?
  enum CodingKeys: String, CodingKey {
    case books = "docs"
  }
}
 
struct BookSearchResultBook: Codable {
  let key, title: String?
  let authorName: [String]?
 
  enum CodingKeys: String, CodingKey {
    case title
    case authorName = "author_name"
    case key
  }
}
 
struct BookSearchRowView: View {
  var book: Book
  var body: some View {
    VStack(alignment: .leading) {
      Text(book.title)
        .font(.headline)
      Text("by \(book.author)")
        .font(.subheadline)
    }
  }
}
 
class ViewModel: ObservableObject {
  @Published
  var terms: String = ""
 
  @Published
  private(set) var result: [Book] = []
 
  @Published
  var isSearching = false
 
  private var cancellables = Set<AnyCancellable>()
 
  init() {
    $terms
      .dropFirst()
      .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
      .removeDuplicates()
      .handleEvents {
        self.isSearching = true
      }
      .await { terms in
        await self.doSearch(matching: terms)
      }
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
      .handleEvents {
        self.isSearching = false
      }
      .assign(to: &$result)
  }
 
  private func doSearch(matching terms: String) async -> [Book] {
    let escapedTerms = terms.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    let url = URL(string: "https://openlibrary.org/search.json?q=\(escapedTerms)")!
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      let result = try JSONDecoder().decode(BookSearchResult.self, from: data)
      return result.books?.compactMap { Book(from: $0) } ?? []
    }
    catch {
      return []
    }
  }
}
 
struct BookSearchView: View {
  @StateObject
  fileprivate var viewModel = ViewModel()
 
  var body: some View {
    List(viewModel.result) { book in
      BookSearchRowView(book: book)
    }
    .overlay {
      if viewModel.isSearching {
        ProgressView()
      }
    }
    .navigationTitle("Open Library")
    .searchable(text: $viewModel.terms)
  }
}
 
extension Publisher {
    func await<T>(_ transform: @escaping (Output) async -> T)
      -> AnyPublisher<T, Failure> {
    flatMap { value -> Future<T, Failure> in
      Future { promise in
        Task {
          let result = await transform(value)
          promise(.success(result))
        }
      }
    }
    .eraseToAnyPublisher()
  }
 
  func handleEvents(_ receiveOutput: (@escaping (Self.Output) -> Void))
      -> Publishers.HandleEvents<Self> {
    self.handleEvents(receiveOutput: receiveOutput)
  }
 
  func handleEvents(_ receiveOutput: (@escaping () -> Void))
      -> Publishers.HandleEvents<Self> {
    self.handleEvents { output in
      receiveOutput()
    }
  }
}
 
let navigationViewController = UINavigationController(
  rootViewController:
    UIHostingController(rootView: BookSearchView())
  )
navigationViewController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
PlaygroundPage.current.liveView = navigationViewController

