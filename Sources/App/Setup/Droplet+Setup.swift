@_exported import Vapor

extension Droplet {
    static var share: Droplet?
    public func setup() throws {
        Droplet.share = self
        try setupRoutes()
    }
}
