//
//  FirstViewController.swift
//  DLM
//
//  Created by Collin Ruffenach on 1/29/15.
//  Copyright (c) 2015 Notion HQ. All rights reserved.
//

import UIKit
import Alamofire
import Realm

let kShowsKey = "shows"
let kShowIDKey = "id"
let kShowDateKey = "date"
let kShowGuestsKey = "guests"

var dataDateFormatter : NSDateFormatter = {
    var formatter = NSDateFormatter();
    formatter.dateFormat = "M/D/yy"
    return formatter;
}()

let testData : Dictionary<String, AnyObject> = [
    kShowsKey : [
        [
            kShowIDKey : 1,
            kShowDateKey : dataDateFormatter.dateFromString("1/7/15")!,
            kShowGuestsKey : [
                "James Gunn"        : ["Writer", "Director"],
                "Sean Gunn"         : ["Actor"],
                "Michael Rooker"    : ["Actor", "Director"]
            ]
        ]
    ]
]

private let _OMDBDateFormatter = OMDBDateParser()

class OMDBDateParser : NSDateFormatter {
    class var sharedFormatter : NSDateFormatter {
        return _OMDBDateFormatter
    }
    
    let dateFormatString = "dd MMM yyyy"
    
    required init(coder aDecoder: NSCoder) {
        super.init()
        self.dateFormat = dateFormatString
    }
    
    override init() {
        super.init()
        self.dateFormat = dateFormatString
    }
}

extension String {
    func urlEncoded() -> String {
        return self.stringByReplacingOccurrencesOfString(" ", withString: "+", options: NSStringCompareOptions.CaseInsensitiveSearch)
    }
    
    func omdbDate() -> NSDate? {
        return OMDBDateParser.sharedFormatter.dateFromString(self)
    }
    
    func rating() -> Movie.Rating {
        switch self {
            case "G":
            return .G
            case "PG":
            return .PG
            case "PG-13":
            return .PG13
            case "R":
            return .R
            case "X":
            return .X
            case "NC-17":
            return .NC17
        default:
            return .NR
        }
    }
    
    func runtimeInterval() -> NSTimeInterval? {
        if let i = self.stringByReplacingOccurrencesOfString(" min", withString: "").toInt() {
            return NSTimeInterval(i * 60)
        }
        return nil;
    }
}

struct Show {
    var id : Int
    var guests : [Guest]
    var date : NSDate
    var location : Location
}

struct Location {
    var id : Int
    var name : String
    var longitude : Double
    var latitude : Double
}

enum Type {
    case LeonardMaltin
    case ABCDeezNuts
    case LastManStanten
    case BuildATitle
    case HowMuchDidThisShitMake
}

protocol Game {
    var type : Type {
        get
    }
}

extension NSDate {
    var year : Int? {
        get {
            return (NSCalendar.currentCalendar().components(NSCalendarUnit.CalendarUnitYear, fromDate: self).year as Int)
        }
    }
}

struct LeonardMaltinGame : Game {
    var type : Type {
        get {
            return .LeonardMaltin
        }
    }
    
    struct Category {
        var id : Int
        var title : String
        var explanation : String
        
        var movies : [Movie]
    }
    
    struct Round {
        
//        var movies : Dictionary<Int, Movie> {
//            return Dictionary<Int, Movie>()
//            get {
//                return self.category.movies.reduce([]) { (xs : [Int], x : Movie) in
//                    if var y = x.date.year {
//                        return xs + [y]
//                    }
//                    return xs
//                }
//            }
//        }()
        
        var name : String {
            get {
                return self.category.title
            }
        }
        
        var explanation : String {
            get {
                return self.category.explanation
            }
        }
        
        var category : Category
    }
    
    var rounds : [Round]
    
}

class ABCDeezNutsGame : Game {
    var type : Type {
        get {
            return .ABCDeezNuts
        }
    }
}

class LastManStantenGame : Game {
    var type : Type {
        get {
            return .LastManStanten
        }
    }
}

class BuildATitleGame : Game {
    var type : Type {
        get {
            return .BuildATitle
        }
    }
}

class HowMuchDidThisShitMakeGame : Game {
    var type : Type {
        get {
            return .HowMuchDidThisShitMake
        }
    }
}

class Movie {
    
    enum Rating : Printable {
        case G
        case PG
        case PG13
        case R
        case X
        case NC17
        case NR
        
        var description: String {
            get {
                switch(self) {
                case .G:
                    return "G"
                case .PG:
                    return "PG"
                case .PG13:
                    return "PG-13"
                case .R:
                    return "R"
                case .X:
                    return "X"
                case .NC17:
                    return "NC17"
                case .NR:
                    return "NR"
                }
            }
        }
    }
    
    var id : String = "UNKNOWN"
    var title : String = ""
    var date : NSDate = NSDate.distantPast() as NSDate
    var boxOffice : Int = 0
    var rating : Rating = .NR
    var runtime : NSTimeInterval = 0
    var runtimeString : String {
        get {
            var r = Int(self.runtime)
            var h = r / (60*60)
            var m = (r-h*(60*60)) / 60
            return "\(h) hr" + (h > 1 ? "s" : "") + " " + "\(m) min" + (m > 1 ? "s" : "")
        }
    }
    
    private var posterURLString : String?
    private var poster : UIImage?
    func poster(eventual : (UIImage? -> ())) -> UIImage? {
        if let posterURL = self.posterURLString {
            OMDBClient.sharedClient.posterAtURL(posterURL) { image in
                if let i = image {
                    self.poster = i
                    eventual(i)
                } else {
                    eventual(image)
                }
            }
        }
        return self.poster
    }
    
    var actors : [Actor] = [Actor]()
    var directors : [Director] = [Director]()
    var writers : [Writer] = [Writer]()
    
    init(info : Dictionary<String, AnyObject>) {
    
        if let id = info["imdbID"] as? String {
            self.id = id
        }
        
        if let title = info["Title"] as? String {
            self.title = title
        }
        
        if let dateString = info["Released"] as? String {
            if let date = dateString.omdbDate() {
                self.date = date
            }
        }
        
        if let ratingString = info["Rated"] as? String {
            self.rating = ratingString.rating()
        }
        
        if let runtimeString = info["Runtime"] as? String {
            if let runtime = runtimeString.runtimeInterval() {
                self.runtime = runtime
            }
        }
        
        self.posterURLString = info["Poster"] as? String
    }
    
}

extension Movie : Printable {
    var description: String {
        get {
            return "{" +
                        "\n" +
                        "\tID: " + self.id +
                        "\n" +
                        "\tTitle: " + self.title +
                        "\n" +
                        "\tDate: " + self.date.description +
                        "\n" +
                        "\tRating: " + self.rating.description +
                        "\n" +
                        "\tRuntime: " + "\(self.runtimeString)" +
                        "\n" +
                   "}"
        }
    }
}

struct Person {
    var id : Int
    var firstName : String
    var lastName : String
    
    var fullName : String {
        return self.firstName + " " + self.lastName
    }
}

func blankPerson() -> Person {
    return Person(id: 0, firstName: "", lastName: "")
}

protocol Personable {
    var person : Person { get }
}

struct Guest : Personable {
    var id : Int
    var person : Person {
        get {
            return blankPerson()
        }
    }
}

struct Actor : Personable {
    var id : Int
    var person : Person {
        get {
            return blankPerson()
        }
    }
}

struct Director : Personable {
    var id : Int
    var person : Person {
        get {
            return blankPerson()
        }
    }
}

struct Writer : Personable {
    var id : Int
    var person : Person {
        get {
            return blankPerson()
        }
    }
}

//API Key: 28648119
//
//Example: http://img.omdbapi.com/?i=tt2294629&apikey=28648119

extension NSURLRequest {
    class func URLRequest(method: Alamofire.Method, URL: URLStringConvertible) -> NSURLRequest {
        let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: URL.URLString)!)
        mutableURLRequest.HTTPMethod = method.rawValue
        
        return mutableURLRequest
    }
}

extension Alamofire.Manager {
    func download(method: Alamofire.Method, URLString: URLStringConvertible, completion : (NSURL -> Void)) -> Alamofire.Request {
        var fileURL : NSURL? = nil
        var destination = Alamofire.Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: NSSearchPathDomainMask.UserDomainMask)
        return self.download(NSURLRequest.URLRequest(method, URL: URLString), destination: { (temporaryURL, response) in
            if let directoryURL = NSFileManager.defaultManager()
                .URLsForDirectory(.DocumentDirectory,
                    inDomains: .UserDomainMask)[0]
                as? NSURL {
                    let pathComponent = response.suggestedFilename
                    var url = directoryURL.URLByAppendingPathComponent(pathComponent!)
                    fileURL = url
                    return url
            }
            fileURL = temporaryURL
            return temporaryURL
        })
            .response {(_, _, _, _) in
                if let u = fileURL {
                    completion(u)
                }
        }
    }
}

private let _OMDBClient = OMDBClient()

class OMDBClient {
    let manager : Alamofire.Manager
    var request : Alamofire.Request?
    
    class var sharedClient : OMDBClient {
        return _OMDBClient
    }
    
    init() {
        var configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        self.manager = Alamofire.Manager(configuration: configuration)
    }
    
    func urlStringWithSearch(text : String) -> String {
        var url = "http://omdbapi.com/?t=" + text.urlEncoded() + "&y=&plot=short&r=json"
        return url
    }
    
    func request(text : String, response : ((Movie?, NSError?) -> Void)) -> Alamofire.Request {
        return self.manager.request(.GET, urlStringWithSearch(text), parameters: nil, encoding: ParameterEncoding.JSON)
                           .responseJSON { (request, maybe_response, json, error) -> Void in
                if let j = json as? Dictionary<String, AnyObject> {
                    response(Movie(info: j), error)
                }
        }
    }
    
    func searchWithText(text : String, response : ((Movie, String) -> Void)) {
        self.request(text) { movie, error in
            if let m = movie {
                response(m, text)
            }
        }
    }
    
    func posterAtURL(urlString : String, poster : (UIImage? -> Void)) {
        
        var image : UIImage? = nil
        
        self.manager.download(.GET, URLString: urlString) { url in
                if let i = UIImage(contentsOfFile: url.path!) {
                    image = i
                }
            }
                    .response { (request, response, obj, error) -> Void in
//                        println("REQUEST: \(request)")
//                        if let r = response {
//                            println("RESPONSE: \(r)")
//                        }
//                        println("OBJECT: \(obj)")
//                        if let e = error {
//                            println("ERROR: \(e)")
//                        }
                        
                        poster(image)
        }
        
    }
}

class SearchTableViewController : UITableViewController {
    
    let client : OMDBClient
    var lastSearch : String = ""
    
    override init(style: UITableViewStyle) {
        self.client = OMDBClient()
        super.init(style: style)
    }
    
    required init(coder aDecoder: NSCoder) {
        self.client = OMDBClient()
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        self.client = OMDBClient()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
}

extension SearchTableViewController : UITableViewDelegate, UITableViewDataSource {
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
}

class MoviePosterView : UIView {
    var imageView : UIImageView = UIImageView()
    
    var movie : Movie? {
        didSet {
            if let m = self.movie {
                self.imageView.image = m.poster {
                    if let i = $0 {
                        self.imageView.image = i
                    }
                }
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.imageView)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.addSubview(self.imageView)
    }
    
    override func layoutSubviews() {
        self.imageView.frame = self.bounds
    }
}

class MovieView : UIView {
    
    let moviePosterView = MoviePosterView(frame: CGRectZero)
    var movie : Movie? {
        didSet {
            self.moviePosterView.movie = self.movie
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.moviePosterView)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.addSubview(self.moviePosterView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        moviePosterView.frame = self.bounds
    }
}

class FirstViewController: UIViewController {
    
    var lastSearch : String = ""
    var searchBar = UISearchBar()
    var movieView = MovieView(frame: CGRectZero)
    var movie : Movie? {
        didSet {
            println(movie)
            self.movieView.movie = self.movie
        }
    }
    
    override func viewDidLoad() {
        
        self.view.addSubview(self.movieView)

        self.searchBar.sizeToFit()
        self.searchBar.delegate = self
        self.searchBar.showsCancelButton = true
        self.view.addSubview(self.searchBar)
    }
    
    override func viewWillLayoutSubviews() {
        searchBar.frame = CGRect(
            x: 0,
            y: self.topLayoutGuide.length,
            width: CGRectGetWidth(self.view.bounds),
            height: CGRectGetHeight(searchBar.bounds)
        )
        self.movieView.frame = self.view.bounds
    }
}

extension FirstViewController : UISearchControllerDelegate, UISearchBarDelegate {

    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        self.lastSearch = searchText;
        OMDBClient.sharedClient.searchWithText(searchText) { movie, search in
            println("Last Search: " + self.lastSearch)
            if (self.lastSearch == search) {
                self.movie = movie
            }
        }
    }
}