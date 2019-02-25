import FluentProvider
import MySQLProvider
import AdminPanel
import LeafProvider
import AuthProvider


extension Config {
    public func setup() throws {
        // allow fuzzy conversions for these types
        // (add your own types here)
        Node.fuzzy = [Row.self, JSON.self, Node.self]

        try setupProviders()
        try setupPreparations()
        addConfigurable(command: AdminPanel.Seeder.init, name: "seeder")
        addConfigurable(middleware: T1Middleware(), name: "version")
    }
    
    /// Configure providers
    private func setupProviders() throws {
        try addProvider(FluentProvider.Provider.self)
        try addProvider(MySQLProvider.Provider.self)
        try addProvider(AdminPanel.Provider.self)
        try addProvider(LeafProvider.Provider.self)
        try addProvider(AuthProvider.Provider.self)
    }
    
    /// Add all models that should have their
    /// schemas prepared before the app boots
    private func setupPreparations() throws {
        preparations.append(Level.self)
        preparations.append(User.self)
        preparations.append(AuthToken.self)
        preparations.append(Topic.self)
        preparations.append(Vocabulary.self)
        preparations.append(Example.self)
        preparations.append(XIIComment.self)
        preparations.append(Score.self)
        preparations.append(Pivot<Topic, Vocabulary>.self)
        preparations.append(Favorite.self)
    }
}
