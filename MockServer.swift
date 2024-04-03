import Foundation
import Network

final class MockServer {

    private var listener: NWListener
    private var connectionsByID: [Int: Connection] = [:]

    init() {
        let port = NWEndpoint.Port(integerLiteral: 8080)
        listener = try! NWListener(using: .init(tls: nil, tcp: .init()), on: port)
    }

    func start() {
        listener.stateUpdateHandler = stateDidChange(to:)
        listener.newConnectionHandler = didAccept(nwConnection:)
        listener.start(queue: .global())
        print("Mock server started listening on port: \(listener.port!)")
    }

    func stop() {
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        listener.cancel()
        for connection in connectionsByID.values {
            connection.stop()
            connection.didStopCallback = nil
        }
    }

    private func stateDidChange(to newState: NWListener.State) {
        switch newState {
        case .failed(let error):
            print("Mock server failed: \(error)")
            stop()

        case .cancelled:
            stop()

        default:
            break
        }
    }

    private func didAccept(nwConnection: NWConnection) {
        let connection = Connection(nwConnection: nwConnection)
        connectionsByID[connection.id] = connection
        connection.didStopCallback = { [weak self] _ in
            self?.connectionDidStop(connection)
        }
        connection.start()
        print("server did open connection \(connection.id)")
    }

    private func connectionDidStop(_ connection: Connection) {
        connectionsByID.removeValue(forKey: connection.id)
    }
}

final class Connection {
    private static var nextID: Int = 0
    let nwConnection: NWConnection
    var didStopCallback: ((Error?) -> Void)? = nil
    let id: Int
    let MTU = 65536

    init(nwConnection: NWConnection) {
        self.nwConnection = nwConnection
        self.id = Connection.nextID
        Connection.nextID += 1
    }

    func start() {
        nwConnection.stateUpdateHandler = stateDidChange(to:)
        setupReceive()
        nwConnection.start(queue: .global())
    }

    func stop(error: Error? = nil) {
        nwConnection.stateUpdateHandler = nil
        nwConnection.cancel()
        if let callback = didStopCallback {
            didStopCallback = nil
            callback(error)
        }
    }

    private func setupReceive() {
        nwConnection.receive(minimumIncompleteLength: 1, maximumLength: MTU) { [weak self] (data, _, isComplete, error) in
            if data != nil {
                self?.respond()
            } else if let error = error {
                self?.stop(error: error)
            } else {
                self?.setupReceive()
            }
        }
    }

    func respond() {
        nwConnection.send(content: Data.badResponse, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                self?.stop(error: error)
                return
            }
            self?.stop()
        }))
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .failed(let error):
            stop(error: error)
        default: break
        }
    }
}

extension Data {
    static func response(json: String) -> Data {
        let message = "OK"
        let statusCode = 200
        let dateString = DateFormatter.http.string(from: Date())
        return """
        HTTP/1.1 \(statusCode) \(message)
        Date: \(dateString)
        Server: mock-server
        Content-Type: application/json
        Content-Length: \(json.utf8.count)
        Connection: close

        \(json)
        """.data(using: .utf8) ?? Data()
    }

    static var badResponse: Data {
        let message = "Not Found"
        let statusCode = 200
        let dateString = DateFormatter.http.string(from: Date())
        return """
        HTTP/1.1 \(statusCode) \(message)
        Date: \(dateString)
        Server: mock-server
        Content-Type: application/json
        Connection: close

        """.data(using: .utf8) ?? Data()
    }
}

extension DateFormatter {
    static var http: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter
    }
}




let server = MockServer()
server.start()

RunLoop.current.run()




