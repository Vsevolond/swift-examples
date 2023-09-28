import Network
import PlaygroundSupport
import SwiftUI

class UdpListener: NSObject, ObservableObject {
    
    private var connection: NWConnection?
    private var listener: NWListener?
    
    @Published var incoming: String = ""
    
    func start(port: NWEndpoint.Port) {
        do {
            self.listener = try NWListener(using: .udp, on: port)
        } catch {
            print("exception upon creating listener")
        }
        
        guard let _ = listener else { return }
        
        prepareUpdateHandler()
        prepareNewConnectionHandler()
        
        self.listener?.start(queue: .main)
    }
    
    func prepareUpdateHandler() {
        self.listener?.stateUpdateHandler = {(newState) in
            switch newState {
            case .ready:
                print("ready")
            default:
                break
            }
        }
    }
    
    func prepareNewConnectionHandler() {
        self.listener?.newConnectionHandler = {(newConnection) in
            newConnection.stateUpdateHandler = {newState in
                switch newState {
                case .ready:
                    print("ready")
                    self.receive(on: newConnection)
                default:
                    break
                }
            }
            newConnection.start(queue: DispatchQueue(label: "newconn"))
        }
    }
    
    func receive(on connection: NWConnection) {
        connection.receiveMessage { (data, context, isComplete, error) in
            if let error = error {
                print(error)
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("unable to receive data")
                return
            }
            
            DispatchQueue.main.async {
                self.incoming = String(decoding: data, as: UTF8.self)
                print(self.incoming)
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var udpListener = UdpListener()
    
    let udpPort = NWEndpoint.Port.init(integerLiteral: 54321)
    
    var body: some View {
        Text("\(udpListener.incoming)")
            .onAppear {
                udpListener.start(port: self.udpPort)
            }
    }
}

PlaygroundPage.current.setLiveView(ContentView())
