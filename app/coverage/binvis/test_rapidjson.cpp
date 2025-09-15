#include <iostream>
#include <rapidjson/document.h>
#include <rapidjson/writer.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/prettywriter.h>

using namespace rapidjson;

int main() {
    // Create a JSON document
    Document doc;
    doc.SetObject();
    
    // Add some test data
    doc.AddMember("name", "test_coverage", doc.GetAllocator());
    doc.AddMember("version", "1.0", doc.GetAllocator());
    doc.AddMember("enabled", true, doc.GetAllocator());
    
    // Create an array
    Value array(kArrayType);
    array.PushBack("item1", doc.GetAllocator());
    array.PushBack("item2", doc.GetAllocator());
    array.PushBack(42, doc.GetAllocator());
    doc.AddMember("items", array, doc.GetAllocator());
    
    // Create a nested object
    Value nested(kObjectType);
    nested.AddMember("type", "coverage_data", doc.GetAllocator());
    nested.AddMember("count", 100, doc.GetAllocator());
    doc.AddMember("data", nested, doc.GetAllocator());
    
    // Convert to JSON string with pretty formatting
    StringBuffer buffer;
    PrettyWriter<StringBuffer> writer(buffer);
    doc.Accept(writer);
    
    // Output the JSON
    std::cout << "RapidJSON Test Output:" << std::endl;
    std::cout << buffer.GetString() << std::endl;
    
    // Test parsing JSON
    const char* json = "{\"test\": \"parsing\", \"number\": 123, \"array\": [1, 2, 3]}";
    Document parseDoc;
    parseDoc.Parse(json);
    
    if (parseDoc.HasParseError()) {
        std::cout << "Parse error!" << std::endl;
        return 1;
    }
    
    std::cout << "\nParsed JSON:" << std::endl;
    std::cout << "test: " << parseDoc["test"].GetString() << std::endl;
    std::cout << "number: " << parseDoc["number"].GetInt() << std::endl;
    std::cout << "array[0]: " << parseDoc["array"][0].GetInt() << std::endl;
    
    std::cout << "\nRapidJSON is working correctly!" << std::endl;
    return 0;
}
