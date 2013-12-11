Purpose
--------------

FastCoder is a replacement for NSPropertyList and NSJSONSerializer for Mac and iOS. It is intended to eventually replace NSKeyedArchiver/Unarchiver as well.

The design goals of the FastCoder library are to provide fast, flexible, secure objective C object graph serialization.

FastCoder is already faster (on average) for reading than any of the built-in serialization mechanisms in Cocoa, and is faster for writing than any format apart from JSON. File size is comparable to the other methods. 

FastCoder supports more data types than either JSON or Plist coding (including NSSet and NSOrderedSet), and allows all supported ata types to be used as the keys in a dictionary, not just strings. The intention is to eventually support arbitrary object encoding.


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 7.0 / Mac OS 10.9 (Xcode 5.0, Apple LLVM compiler 5.0)
* Earliest supported deployment target - iOS 5.0 / Mac OS 10.7
* Earliest compatible deployment target - iOS 4.0 / Mac OS 10.6

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

FastCoder is compatible with both ARC and non-ARC compile targets, however performance is significantly better when running with ARC disabled, and it is recommended that you apply the -fno-objc-arc compiler flag to the FastCoder.m class. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click FastCoder.m in the list and type -fno-objc-arc into the popover.


Thread Safety
--------------

It is safe to call the FastCoder encoding and decoding method concurrently from multiple threads. It should be safe to encode the same object concurrently on multiple threads provided that you do not mutate the object while it is being encoded.


Installation
--------------

To use FastCoder, just drag the FastCoder.h and .m files into your project.


FastCoder methods
-----------------------------

FastCoder implements the following methods:

    + (id)objectWithData:(NSData *)data;
    
Constructs an object tree from an FastCoded data object and returns it.

    + (NSData *)dataWithRootObject:(id)object;
    
Archives an object graph as a block of data, which can then be saved to a file or transmitted.


Data structure
---------------------------

The FastArchive format is very simple: There is a header consisting of a a 32-bit identifier, followed by two 16-bit version numbers (major and minor) and then one or more chunks.

Each chunk consists of a 32-bit type identifier, followed by 0 or more additional bytes of data, depending on the chunk type.

Commonly used types and values are represented by their own chunk in order to reduce file size and processing overhead. Other types such as strings or collections are encoded in the sequence of bytes that follow the chunk.

Chunks are always 32-bit (4-byte) aligned. Most chunk types have sizes that are a multiple of 32 bits anyway, but strings and data objects whose length is not an exact multiple of 4 bytes are padded to the nearest 4-byte offset.

The currently supported chunk types are:

    FCTypeNull              an NSNull value
    FCTypeAlias,            an alias to an previously encoded chunk in the file
    FCTypeString,           an NSString instance
    FCTypeDictionary,       an NSDictionary instance
    FCTypeArray,            an NSArray instance
    FCTypeSet,              an NSSet instance
    FCTypeOrderedSet,       an NSOrderedSet instance
    FCTypeTrue,             a boolean YES value
    FCTypeFalse,            a boolean NO value
    FCTypeInt32,            a 32-bit integer value
    FCTypeInt64,            a 64-bit integer value
    FCTypeFloat32,          a 32-bit floating point value
    FCTypeFloat64,          a 64-bit floating point value
    FCTypeData,             an NSData instance
    FCTypeDate              an NSDate instance
