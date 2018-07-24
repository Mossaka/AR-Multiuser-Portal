/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience extensions on system types.
*/

import simd
import ARKit

extension ARFrame.WorldMappingStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notAvailable:
            return "Not Available"
        case .limited:
            return "Limited"
        case .extending:
            return "Extending"
        case .mapped:
            return "Mapped"
        }
    }
}

extension float4x4 {
    var translation: float3 {
        return float3(columns.3.x, columns.3.y, columns.3.z)
    }

    init(translation vector: float3) {
        self.init(float4(1, 0, 0, 0),
                  float4(0, 1, 0, 0),
                  float4(0, 0, 1, 0),
                  float4(vector.x, vector.y, vector.z, 1))
    }
}

extension float4 {
    var xyz: float3 {
        return float3(x, y, z)
    }
}

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

func realDecoder(from data: Data) -> (SCNVector3, SCNVector3)? {
    guard let datatoTuple = String(data: data, encoding: String.Encoding.utf8) else {
        return nil
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

//func realEncoder(from transform: SCNMatrix4) -> Data {
//    if let data = "\(transform.m11),\(transform.m12),\(transform.m13),\(transform.m14),\(transform.m21),\(transform.m22),\(transform.m23),\(transform.m24),\(transform.m31),\(transform.m32),\(transform.m33),\(transform.m34),\(transform.m41),\(transform.m42),\(transform.m43),\(transform.m44),".data(using: .utf8) {
//        return data
//    } else {
//        fatalError("can't convert transform \(transform) to data")
//    }
//}
//
//func realDecoder(from data: Data) -> SCNMatrix4? {
//    guard let dataToString = String(data: data, encoding: String.Encoding.utf8) else {
//        return nil
//    }
//
//    let StringArray = dataToString.components(separatedBy: ",")
////    assert(StringArray.count == 16)
//
//    let FloatArray = StringArray.map ({
//        (elem: String) -> Float in
//        if let convertedElem = Float(elem) { return convertedElem }
//        else { fatalError("Can't convert to float") }
//    })
//    if FloatArray.count != 16 { return nil }
//    let SCNMatrixToReturn = SCNMatrix4(m11: FloatArray[0], m12: FloatArray[1], m13: FloatArray[2], m14: FloatArray[3], m21: FloatArray[4], m22: FloatArray[5], m23: FloatArray[6], m24: FloatArray[7], m31: FloatArray[8], m32: FloatArray[9], m33: FloatArray[10], m34: FloatArray[11], m41: FloatArray[12], m42: FloatArray[13], m43: FloatArray[14], m44: FloatArray[15])
//    return SCNMatrixToReturn
//}
//
//extension SCNMatrix4 {
//    func pprint() {
//        print("""
//            m11: \(self.m11), m11: \(self.m12), m11: \(self.m31), m11: \(self.m41) \n
//            m11: \(self.m12), m11: \(self.m22), m11: \(self.m32), m11: \(self.m42) \n
//            m11: \(self.m13), m11: \(self.m32), m11: \(self.m33), m11: \(self.m43) \n
//            m11: \(self.m14), m11: \(self.m42), m11: \(self.m34), m11: \(self.m44) \n
//            """)
//    }
//}
