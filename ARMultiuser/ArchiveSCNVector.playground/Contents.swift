import UIKit
import ARKit
import MultipeerConnectivity

let x : SCNFloat = 2.5
let y : SCNFloat = 3.5
let z : SCNFloat = 4.5

let vec = SCNVector3(x,y,z)
let vec2 = SCNVector3(x+1,y+1,z+1)

struct SCNVector3TupleStruct {
    var value: (SCNVector3, SCNVector3)
}

extension SCNVector3TupleStruct {
    func toData() -> Data {
        if let data =  "\(value.0.x),\(value.0.y),\(value.0.z),\(value.1.x),\(value.1.y),\(value.1.z)".data(using: .utf8) {
            return data
        } else { fatalError("can't serialize the SCNVector") }
    }
    
    static func ==(lhs: SCNVector3TupleStruct, rhs: SCNVector3TupleStruct) -> Bool {
        return
            lhs.value.0.x == rhs.value.0.x &&
            lhs.value.0.y == rhs.value.0.y &&
            lhs.value.0.z == rhs.value.0.z &&
            lhs.value.1.x == rhs.value.1.x &&
            lhs.value.1.y == rhs.value.1.y &&
            lhs.value.1.z == rhs.value.1.z
    }
}

extension String {
    func toSCNFloat() -> SCNFloat {
        if let data = Float(self) {
            return SCNFloat(data)
        } else {
            fatalError("can't convert string to SCNFloat")
        }
    }
}

func realEncoder(from pos_dir : (SCNVector3, SCNVector3) ) -> Data {
    let tuple = SCNVector3TupleStruct.init(value: (pos_dir.0, pos_dir.1))
    let data = tuple.toData()
    return data
}

func realDecoder(from data: Data) -> (SCNVector3, SCNVector3) {
    guard let datatoTuple = String(data: data, encoding: String.Encoding.utf8) else {
        fatalError("can't convert data to string")
    }
    let SCNFloatArr = datatoTuple.components(separatedBy: ",")
    let left = SCNFloatArr[0..<3]
    let right = SCNFloatArr[3..<SCNFloatArr.count]
    var vec1arr: [SCNFloat] = []
    var vec2arr: [SCNFloat] = []
    for value in left {
        vec1arr.append(value.toSCNFloat())
    }
    for value in right {
        vec2arr.append(value.toSCNFloat())
    }
    
    let leftVec = SCNVector3(vec1arr[0], vec1arr[1], vec1arr[2])
    let rightVec = SCNVector3(vec2arr[0], vec2arr[1], vec2arr[2])
    return (leftVec, rightVec)
}

SCNVector3TupleStruct.init(value: realDecoder(from: realEncoder(from: (vec, vec2))) ) ==
SCNVector3TupleStruct.init(value: (vec, vec2))
