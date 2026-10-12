import Foundation

/// The credit TVMaze asks for. TVMaze data is licensed under
/// [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/): show the credit with a link
/// back wherever the data appears.
public enum TVMazeAttribution {
    /// "Data provided by TVmaze.com".
    public static let text = "Data provided by TVmaze.com"
    /// https://www.tvmaze.com
    public static let url = URL(string: "https://www.tvmaze.com")!
    /// The data license, CC BY-SA 4.0.
    public static let licenseURL = URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!
}
