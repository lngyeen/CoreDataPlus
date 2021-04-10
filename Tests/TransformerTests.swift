// CoreDataPlus

import XCTest
import CoreData
@testable import CoreDataPlus

final class TransformerTests: CoreDataPlusOnDiskTestCase {
  @objc(Dummy)
  class Dummy: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let name: String
    
    init(name: String) {
      self.name = name
    }
    
    func encode(with coder: NSCoder) {
      coder.encode(name, forKey: "name")
    }
    
    required init?(coder decoder: NSCoder) {
      guard let name = decoder.decodeObject(of: [NSString.self], forKey: "name") as? String else { return nil }
      self.name = name
    }
  }
  
  func testSaveAndFetchTransformableValue() throws {
    let context = container.viewContext
    let car = Car(context: context)
    car.maker = "FIAT"
    car.model = "Panda"
    car.numberPlate = "1"
    car.color = Color(name: "red")
    try context.save()
    context.reset()
    
    let firstCar = try XCTUnwrap(try Car.fetchOne(in: context, where: NSPredicate(value: true)))
    
    let color = try XCTUnwrap(firstCar.color)
    XCTAssertEqual(color.name, "red")
  }
  
  func testSaveAndFetchTransformableValueUsingCustomTransformer() throws {
    let context = container.viewContext
    let car = Car(context: context)
    car.maker = "FIAT"
    car.model = "Panda"
    car.numberPlate = "1"
    car.color = Color(name: "red")
    try context.save()
    context.reset()
    
    let firstCar = try XCTUnwrap(try Car.fetchOne(in: context, where: NSPredicate(value: true)))
    
    let color = try XCTUnwrap(firstCar.color)
    XCTAssertEqual(color.name, "red")
  }
  
  func testTransformerUnregister() {
    XCTAssertFalse(Foundation.ValueTransformer.valueTransformerNames().contains(Transformer<Dummy>.transformerName))
    Transformer<Dummy>.register()
    XCTAssertTrue(Foundation.ValueTransformer.valueTransformerNames().contains(Transformer<Dummy>.transformerName))
    Transformer<Dummy>.unregister()
    XCTAssertFalse(Foundation.ValueTransformer.valueTransformerNames().contains(Transformer<Dummy>.transformerName))
  }
  
  func testDataTransformerUnregister() {
    XCTAssertFalse(Foundation.ValueTransformer.valueTransformerNames().contains(DataTransformer<Dummy>.transformerName))
    DataTransformer<Dummy>.register {
      guard let color = $0 else { return nil }
      return try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
    } reverseTransform: {
      guard let data = $0 else { return nil }
      return try? NSKeyedUnarchiver.unarchivedObject(ofClass: Dummy.self, from: data)
    }
    XCTAssertTrue(Foundation.ValueTransformer.valueTransformerNames().contains(DataTransformer<Dummy>.transformerName))
    Transformer<Dummy>.unregister()
    XCTAssertFalse(Foundation.ValueTransformer.valueTransformerNames().contains(DataTransformer<Dummy>.transformerName))
  }
  
  func testTransformer() throws {
    let transformer = Transformer<Color>()
    let data = transformer.reverseTransformedValue(Color(name: "green"))
    XCTAssertNotNil(data)
    let expectedColor = transformer.transformedValue(data) as? Color
    XCTAssertNotNil(expectedColor)
    let name = try XCTUnwrap(expectedColor?.name)
    XCTAssertEqual(name, "green")
  }
  
  func testCustomTransformer() throws {
    let transformer = DataTransformer<Color> { color -> Data? in
      guard let color = color else { return nil }
      return try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
    } reverseTransform: { data -> Color? in
      guard let data = data else { return nil }
      return try? NSKeyedUnarchiver.unarchivedObject(ofClass: Color.self, from: data)
    }
    let data = transformer.transformedValue(Color(name: "green"))
    XCTAssertNotNil(data)
    let expectedColor = transformer.reverseTransformedValue(data) as? Color
    XCTAssertNotNil(expectedColor)
    let name = try XCTUnwrap(expectedColor?.name)
    XCTAssertEqual(name, "green")
  }
  
  func testDataTransformerWithNSArray() throws {
    let transformer = DataTransformer<NSArray> { array -> Data? in
      guard let array = array else { return nil }
      return try? NSKeyedArchiver.archivedData(withRootObject: array, requiringSecureCoding: true)
    } reverseTransform: { data -> NSArray? in
      guard let data = data else { return nil }
      return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSArray
    }
    
    let array = NSMutableArray()
    array.add(1)
    array.add(Color(name: "green"))
    array.add(Dummy(name: "dummy1"))
    array.add([Dummy(name: "dummy2"), Dummy(name: "dummy2")])
    let data = transformer.transformedValue(NSArray(array: array))
    XCTAssertNotNil(data)
    
    let expectedTransformedValue = transformer.reverseTransformedValue(data)
    let expectedNSArray = try XCTUnwrap(expectedTransformedValue as? NSArray)
    let first = try XCTUnwrap(expectedNSArray.object(at: 0) as? Int)
    let second = try XCTUnwrap(expectedNSArray.object(at: 1) as? Color)
    let third = try XCTUnwrap(expectedNSArray.object(at: 2) as? Dummy)
    let fourth = try XCTUnwrap(expectedNSArray.object(at: 3) as? [Dummy])
    XCTAssertEqual(first, 1)
    XCTAssertEqual(second.name, "green")
    XCTAssertEqual(third.name, "dummy1")
    XCTAssertEqual(fourth.first?.name, "dummy2")
    XCTAssertEqual(fourth.last?.name, "dummy2")
  }
}
