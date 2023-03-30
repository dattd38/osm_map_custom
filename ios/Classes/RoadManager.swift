//
// Created by Dali on 6/20/21.
//

import Foundation
import Alamofire
import MapKit
import Polyline
import TangramMap

typealias ParserJson = ([String: Any?]?) -> Road
typealias RoadHandler = (Road?) -> Void


enum RoadType: String {
    case car = "routed-car"
    case bike = "routed-bike"
    case foot = "routed-foot"
}


protocol PRoadManager {


    func getRoad(wayPoints: [String], typeRoad: RoadType, handler: @escaping RoadHandler)

    func drawRoadOnMap(roadKey: String, on road: Road, for map: TGMapView, roadInfo: RoadInformation?, polyLine: Polyline?) -> TGMarker

}

class RoadManager: PRoadManager {

    public let MANEUVERS: Dictionary<String, Int> = [
        "new name": 2,
        "turn-straight": 1,
        "turn-slight right": 6,
        "turn-right": 7,
        "turn-sharp right": 8,
        "turn-uturn": 12,
        "turn-sharp left": 5,
        "turn-left": 4,
        "turn-slight left": 3,
        "depart": 25,
        "arrive": 24,
        "roundabout-1": 27,
        "roundabout-2": 28,
        "roundabout-3": 29,
        "roundabout-4": 30,
        "roundabout-5": 31,
        "roundabout-6": 32,
        "roundabout-7": 33,
        "roundabout-8": 34,
        "merge-left": 20,
        "merge-sharp left": 20,
        "merge-slight left": 20,
        "merge-right": 21,
        "merge-sharp right": 21,
        "merge-slight right": 21,
        "merge-straight": 22,
        "ramp-left": 17,
        "ramp-sharp left": 17,
        "ramp-slight left": 17,
        "ramp-right": 18,
        "ramp-sharp right": 18,
        "ramp-slight right": 18,
        "ramp-straight": 19
    ];

    public let DIRECTIONS = [
        1: ["en": "Continue[ on %s]", "de": ""],
        2: ["en": "[Go on %s]", "de": ""],
        3: ["en": "Turn slight left[ on %s]", "de": ""],
        4: ["en": "Turn left[ on %s]", "de": ""],
        5: ["en": "Turn sharp left[ on %s]", "de": ""],
        6: ["en": "Turn slight right[ on %s]", "de": ""],
        7: ["en": "Turn right[ on %s]", "de": ""],
        8: ["en": "Turn sharp right[ on %s]", "de": ""],
        12: ["en": "U-Turn[ on %s]", "de": ""],
        17: ["en": "Take the ramp on the left[ on %s]", "de": ""],
        18: ["en": "Take the ramp on the right[ on %s", "de": ""],
        19: ["en": "Take the ramp straight ahead[ on %s]", "de": ""],
        24: ["en": "You have reached a waypoint of your trip", "de": ""],
        25: ["en": "Head {direction} [on %s]", "de": ""],
        27: ["en": "Enter roundabout and leave at first exit[ on %s]", "de": ""],
        28: ["en": "Enter roundabout and leave at second exit[ on %s]", "de": ""],
        29: ["en": "Enter roundabout and leave at third exit[ on %s]", "de": ""],
        30: ["en": "Enter roundabout and leave at fourth exit[ on %s]", "de": ""],
        31: ["en": "Enter roundabout and leave at fifth exit[ on %s]", "de": ""],
        32: ["en": "Enter roundabout and leave at sixth exit[ on %s]", "de": ""],
        33: ["en": "Enter roundabout and leave at seventh exit[ on %s]", "de": ""],
        34: ["en": "Enter roundabout and leave at eighth exit[ on %s]", "de": ""],
    ]

    private var road: Road? = nil
    private var lastMarkerRoad: RoadFolder? = nil
    private(set) var roads: [RoadFolder] = [RoadFolder]()

    init() {

    }


    public func clearRoads(for map: TGMapView) {
        if (lastMarkerRoad != nil) {
            map.markerRemove(lastMarkerRoad!.tgRouteMarker)
            lastMarkerRoad = nil
        }
        if !roads.isEmpty {
            roads.forEach { folder in
                map.markerRemove(folder.tgRouteMarker)
            }
        }
    }

    func removeLastRoad(for map: TGMapView) {
        if let lastRoad = lastMarkerRoad {
            removeRoadFolder(folder: lastRoad, for: map)
            lastMarkerRoad = nil
        }
    }

    func removeRoadByKey(key: String, for map: TGMapView) {
        let folderRoad = roads.first { folder in
            folder.id == key
        }
        if let road = folderRoad {
            removeRoadFolder(folder: road, for: map)
        }
    }

    func removeRoadFolder(folder: RoadFolder, for map: TGMapView) {
        map.markerRemove(folder.tgRouteMarker)
    }

    public func drawRoadOnMap(roadKey: String, on road: Road, for map: TGMapView, roadInfo: RoadInformation?, polyLine: Polyline? = nil) -> TGMarker {
        /*if(lastMarkerRoad != nil){
           removeRoadFolder(folder: lastMarkerRoad!, for: map)
        }*/
        let marker = map.markerAdd()
        marker.stylingString = "{ style: 'lines',interactive: true, color: '\(road.roadData.roadColor)', width: \(road.roadData.roadWidth), outline : { color: '\(road.roadData.roadBorderColor)', width: '\(road.roadData.roadBorderWidth)' } , order: 1500 }"

        var route = polyLine
        if (route == nil) {
            route = Polyline(encodedPolyline: road.mRouteHigh, precision: 1e5)
        }
        let tgPolyline = TGGeoPolyline(coordinates: route!.coordinates!, count: UInt(route!.coordinates!.count))
        marker.polyline = tgPolyline
        let folder = RoadFolder(id: roadKey, tgRouteMarker: marker, roadInformation: roadInfo)
        self.roads.append(folder)
        lastMarkerRoad = folder
        return marker
    }

    public func drawMultiRoadsOnMap(on roads: [(String, Road)], for map: TGMapView) {
        clearRoads(for: map)
        for (key, road) in roads {
            let marker = map.markerAdd()
            marker.stylingString = "{ style: 'lines',interactive: true, color: '\(road.roadData.roadColor)', width: \(road.roadData.roadWidth), order: 1500 }"
            let route = Polyline(encodedPolyline: road.mRouteHigh, precision: 1e5)
            let tgPolyline = TGGeoPolyline(coordinates: route.coordinates!, count: UInt(route.coordinates!.count))
            marker.polyline = tgPolyline
            self.roads.append(RoadFolder(id: key, tgRouteMarker: marker, roadInformation: nil))
        }
        /*
        lastMarkerRoad = marker */
    }

    func getRoad(wayPoints: [String], typeRoad: RoadType, handler: @escaping RoadHandler) {
        let serverURL = buildURL(wayPoints, typeRoad.rawValue)
        guard let url = Bundle(for: type(of: self)).url(forResource: "en", withExtension: "json") else {
            return print("File not found")
        }
        var contentLangEn: [String:Any] = [String:Any]()
        do {
            let data = try String(contentsOf: url).data(using: .utf8)
            contentLangEn = parse(jsonData: data)
        } catch let error {
            print(error)
        }

        DispatchQueue.global(qos: .background).async {
            self.httpCall(url: serverURL) { json in
                if json != nil {
                    let road = self.parserRoad(json: json!, instructionResource: contentLangEn)
                    DispatchQueue.main.async {
                        self.road = road
                        handler(road)
                    }
                } else {
                    DispatchQueue.main.async {
                        handler(nil)
                    }
                }
            }
        }
    }


    func buildURL(_ waysPoints: [String], _ typeRoad: String, alternative: Bool = false) -> String {
        let serverBaseURL = "https://routing.openstreetmap.de/\(typeRoad)/route/v1/driving/"
        let points = waysPoints.reduce("") { (result, s) in
            "\(result);\(s)"
        }
        var stringWayPoint = points
        stringWayPoint.removeFirst()


        return "\(serverBaseURL)\(stringWayPoint)?alternatives=\(alternative)&overview=full&steps=true"
    }

    private func httpCall(url: String, parseHandler: @escaping (_ json: [String: Any?]?) -> Void) {
        AF.request(url, method: .get).responseJSON { response in
            if response.data != nil {
                let data = response.value as? [String: Any?]
                parseHandler(data!)
            } else {
                parseHandler(nil)
            }
        }
    }

    private func parserRoad(json: [String: Any?], instructionResource: [String:Any]) -> Road {
        var road: Road = Road()
        if json.keys.contains("routes") {
            let routes = json["routes"] as! [[String: Any?]]
            routes.forEach { route in
                road.distance = (route["distance"] as! Double) / 1000
                road.duration = route["duration"] as! Double
                road.mRouteHigh = route["geometry"] as! String
                let jsonLegs = route["legs"] as! [[String: Any]]
                jsonLegs.enumerated().forEach { indexLeg,jLeg in
                    var legR: RoadLeg = RoadLeg()
                    legR.distance = (jLeg["distance"] as! Double) / 1000
                    legR.duration = jLeg["duration"] as! Double

                    let jsonSteps = jLeg["steps"] as! [[String: Any?]]
                    var lastName = ""
                    var lastNode: RoadNode? = nil
                    jsonSteps.enumerated().forEach { index,step in
                        let maneuver = (step["maneuver"] as! [String: Any?])
                        let location = maneuver["location"] as! [Double]
                        var node = RoadNode(
                                location: CLLocationCoordinate2D(
                                        latitude: (location)[1],
                                        longitude: (location)[0]
                                )
                        )
                        node.distance = (step["distance"] as! Double) / 1000
                        node.duration = step["duration"] as! Double
                        var direction = maneuver["type"] as! String
                        let roadStep = RoadStep(json: step)
                        node.instruction = roadStep.buildInstruction(instructions: instructionResource,options: [
                            "legIndex":indexLeg , "legCount" : jsonLegs.count - 1
                        ])
                        if lastNode != nil && node.maneuver != 2 && lastName == roadStep.name {
                            lastNode?.duration += node.duration
                            lastNode?.distance += node.distance
                        } else {
                            road.steps.append(node)
                            lastNode = node
                            lastName = roadStep.name
                        }


                    }

                }
            }
        }
        /*json.forEach { key, value in
            if key == "routes" {

            }
        }*/
        return road

    }
    private func parse(jsonData: Data?) -> [String:Any] {
        if jsonData == nil {
            return [String:Any]()
        }
        do {
            let decodedData = try JSONSerialization.jsonObject(with: jsonData!)
            return decodedData as! [String:Any]
        } catch {
            print("decode error")
        }
        return [String:Any]()
    }


 }

extension RoadManager {
    /**
	 * mapping from OSRM StepManeuver types to MapQuest maneuver IDs:
	 */


//From: Project-OSRM-Web / WebContent / localization / OSRM.Locale.en.js
// driving directions
// %s: road name
// %d: direction => removed
// <*>: will only be printed when there actually is a road name
    static let DIRECTIONS: [Int: String] = [
        1: "", 2: "", 3: "",
    ]

}
