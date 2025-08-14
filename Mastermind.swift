#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation

struct CreateGameResponse: Codable {
    let game_id: String
}

struct GuessResponse: Codable {
    let black: Int
    let white: Int
}

struct ErrorResponse: Codable {
    let error: String
}

class MastermindAPI {
    private let baseURL = "https://mastermind.darkube.app"
    
    func createGame(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/game") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(CreateGameResponse.self, from: data)
                completion(.success(response.game_id))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    func submitGuess(gameID: String, guess: String, completion: @escaping (Result<GuessResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/guess") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "game_id": gameID,
            "guess": guess
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, !data.isEmpty else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            if let guessResponse = try? JSONDecoder().decode(GuessResponse.self, from: data) {
                completion(.success(guessResponse))
            } else if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse.error])))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
            }
        }
        
        task.resume()
    }
    
    func deleteGame(gameID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/game/\(gameID)") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
        
        task.resume()
    }
}

class MastermindGame {
    private let api = MastermindAPI()
    private var gameID: String?
    
    func start() {
        print("Welcome to Mastermind!")
        print("Guess the 4-digit code (digits 1-6).")
        print("B = correct digit in correct position")
        print("W = correct digit in wrong position")
        print("Type 'exit' to quit.\n")
        
        api.createGame { [weak self] result in
            switch result {
            case .success(let id):
                self?.gameID = id
                print("New game started. Enter your guess:")
                self?.waitForInput()
            case .failure(let error):
                print("Error starting game: \(error.localizedDescription)")
            }
        }
        
        RunLoop.main.run()
    }
    
    private func waitForInput() {
        print("> ", terminator: "")
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            waitForInput()
            return
        }
        
        if input.lowercased() == "exit" {
            if let gameID = gameID {
                api.deleteGame(gameID: gameID) { _ in
                    print("Game ended. Goodbye!")
                    exit(0)
                }
            } else {
                print("Goodbye!")
                exit(0)
            }
            return
        }
        
        guard input.count == 4 else {
            print("Guess must be 4 digits long")
            waitForInput()
            return
        }
        
        guard input.rangeOfCharacter(from: CharacterSet(charactersIn: "123456").inverted) == nil else {
            print("Each digit must be between 1 and 6")
            waitForInput()
            return
        }
        
        if let gameID = gameID {
            api.submitGuess(gameID: gameID, guess: input) { [weak self] result in
                switch result {
                case .success(let response):
                    let feedback = String(repeating: "B", count: response.black) + 
                                    String(repeating: "W", count: response.white)
                    print("Feedback: \(feedback)")
                    
                    if response.black == 4 {
                        print("Congratulations! You guessed the code!")
                        self?.api.deleteGame(gameID: gameID) { _ in
                            exit(0)
                        }
                    } else {
                        self?.waitForInput()
                    }
                case .failure(let error):
                    print("Error submitting guess: \(error.localizedDescription)")
                    self?.waitForInput()
                }
            }
        } else {
            print("No active game. Please start a new game.")
            waitForInput()
        }
    }
}

let game = MastermindGame()
game.start()
