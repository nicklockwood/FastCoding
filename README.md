[![Build Status](https://travis-ci.org/nicklockwood/FastCoding.svg)](https://travis-ci.org/nicklockwood/FastCoding)


Purpose
--------------

FastCoder is a high-performance binary serialization format for Cocoa objects and object graphs. It is intended as a replacement for NSPropertyList, NSJSONSerializer, NSKeyedArchiver/Unarchiver and Core Data.

The design goals of the FastCoder library are to be fast, flexible and secure.

FastCoder is already faster (on average) for reading than any of the built-in serialization mechanisms in Cocoa, and is faster for writing than any mechanism except for JSON (which doesn't support arbitrary object types). File size is smaller than NSKeyedArchiver, and comparable to the other methods. 

FastCoder supports more data types than either JSON or Plist coding (including NSURL, NSValue, NSSet and NSOrderedSet), and allows all supported object types to be used as the keys in a dictionary, not just strings.

FastCoder can also serialize your custom classes automatically using property inspection. For cases where this doesn't work automatically, you can easily implement your own serialization using the FastCoding or NSCoding protocols.


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 8.1 / Mac OS 10.10 (Xcode 6.1, Apple LLVM compiler 6.0)
* Earliest supported deployment target - iOS 5.0 / Mac OS 10.7
* Earliest compatible deployment target - iOS 4.0 / Mac OS 10.6

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

FastCoder is compatible with both ARC and non-ARC compile targets, however, performance is better when running with ARC disabled, and it is recommended that you apply the `-fno-objc-arc` compiler flag to the FastCoder.m class. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click FastCoder.m in the list and type `-fno-objc-arc` into the popover.


Thread Safety
--------------

It is safe to call the FastCoder encoding and decoding class methods concurrently from multiple threads. It should also be safe to encode the same object concurrently on multiple threads provided that you do not mutate the object while it is being encoded.


Installation
--------------

To use FastCoder, just drag the FastCoder.h and .m files into your project.


Security
--------------

The FastCoding parser checks for buffer overflow errors whilst parsing, and will throw an exception if the data instructs it to try to read past the end of the data file. This should prevent most kinds of code injection attack.

Whilst it is not possible to use a FastCoded file to inject code, as with NSCoding, an attacker could use a modified FastCoded file to cause unexpected classes to be created in your object graph, which might present a potential attack risk (note that only classes that already exist in your code base or a built-in Cocoa Framework can be created this way).

For the time being, it is best not to try to load arbitrary FastCoded files from an untrusted source (although it is fine to use them for saving data internally within your application's sandbox). If you want to exchange FastCoded files between apps or users, use only the explicitly supported class types (listed below) and load the file using `propertyListWithData:`, which only supports safe types and will refuse to load a file containing unknown classes. A future release of the FastCoding library will add more sophisticated whitelisting capabilities.


Supported Classes
------------------

FastCoding supports the following class types natively:

    NSNull
    NSNumber
    NSDecimalNumber
    NSValue (only the following subtypes)
        CGPoint/NSPoint
        CGSize/NSSize
        CGRect/NSRect
        CGVector
        NSRange
        CGAffineTransform
        CATransform3D
    NSString
    NSMutableString
    NSArray
    NSMutableArray
    NSDictionary
    NSMutableDictionary
    NSSet
    NSMutableSet
    NSOrderedSet
    NSMutableOrderedSet
    NSIndexSet
    NSMutableIndexSet
    NSData
    NSMutableData
    NSDate

FastCoding also automatically supports any class that complies with the NSCoding protocol, or any class whose properties are all KVC-compliant, or that explicity implements the FastCoding protocol.


FastCoder methods
-----------------------------

FastCoder implements the following methods:

    + (id)objectWithData:(NSData *)data;
    
Constructs an object tree from an FastCoded data object and returns it. FastCoder does not currently provide any mechanism for class validation or substitution, so this method should not be used for loading files with unknown provenance (i.e. where you can't guarantee where the file came from, or that the file hasn't been tampered with). For exchanging files between apps, or for user-accessible documents, it is recommended that you use the `propertyListWithData:` method for loading the file instead (although this does not support arbitrary classes).
 
If an unknown class type is encountered in the file, it will be loaded as a dictionary of properties that can be converted back into a real class later (see 'Bootstrapping', below). Attempting to load a malformed or corrupt file will throw an exception (caught internally) and return nil.

    + (id)propertyListWithData:(NSData *)data;
    
Like `objectWithData:`, but this method is limited to loading "safe" object types such as `NSString`, `NSNumber`, `NSArray`, etc. Despite the name, this method is not actually limited to objects supported by `NSPropertyList` - for example it supports `NSNull` and `NSURL` - however it is safe to use for loading files from untrusted sources. Also, unlike ordinary property list methods, this can handle circular references, aliased objects and mutable containers like `NSMutableArray`. Attempting to load a malformed or corrupt file, or one containing unsupported classes, will throw an exception (caught internally) and return nil.

    + (NSData *)dataWithRootObject:(id)object;
    
Archives an object graph as a block of data, which can then be saved to a file or transmitted via a network. The file can be loaded again using `objectWithData:`, or `propertyListWithData:` (provided that it only contains supported class types).


The FastCoding Protocol
-----------------------------

FastCoding supports encoding/decoding of arbitrary objects using the FastCoding protocol. The FastCoding protocol is an *informal* protocol, implemented as a category on NSObject. The protocol consists of the following methods:

    + (NSArray *)fastCodingKeys;
    
This method returns a list of property names that should be encoded/decoded for an object. The default implementation automatically detects all of the non-virtual (i.e. ivar-backed) @properties (including private and read-only properties) of the object and returns them, so in most cases it is not necessary to override this method. **NOTE:** if you override `+fastCodingKeys`, you should only include property keys for the current class, not properties that are inherited from the superclass.
    
    - (id)awakeAfterFastCoding;

This method is called after an object has been deserialized using the FastCoding protocol, and all of its properties have been set. The deserialized object will be replaced by the one returned by this method, so you can use this method to either modify or completely replace the object. The default implementation just returns `self`. **NOTE**: returning a different object from `-awakeAfterFastCoding` may lead to unexpected behaviour if the object being decoded (or any of its children) contains a reference to itself.

    - (Class)classForFastCoding;
    
This method is used to supply an alternative class to use for coding/decoding an object. This works the same way as the `-classForCoder` method of NSCoding, and by default returns the same value.
 
    - (BOOL)preferFastCoding;

Because FastCoding automatically supports NSCoding, any object that conforms to the NSCoding protocol (except for types that are explicitly supported by FastCoding) will be encoded using the NSCoding methods by default. This is better for compatibility purposes, but may be signficantly slower than using the FastCoding protocol. If your class supports both NSCoding and FastCoding, and you would prefer FastCoder to use the FastCoding protocol, override this method and return `YES` (the default value is `NO`).
 

Overriding Default FastCoding Behaviour
-------------------------------------------

If you wish to exclude certain properties of your object from being encoded, you can do so in any of the following ways:

* Only use an ivar, without declaring a matching `@property`.
* Change the name of the ivar to something that is not KVC compliant (i.e. not the same as the property, or the property name with an _ prefix). You can do this using the `@synthesize` directive, e.g. `@synthesize foo = unencodableFoo;`
* Override the +fastCodingKeys method

If you wish to encode additional data that is not represented by an `@property`, override the `+fastCodingKeys` method and add the names of your virtual properties. You will need to implement suitable setter/getter methods for these properties, or the encoding/decoding process won't work.

If you wish to substitute a different class for decoding, you can implement the `-classForFastCoding` method and FastCoding will encode the object as that class instead. If you wish to substitute a different object after decoding, use the `-awakeAfterFastCoding` method.

If you have removed or renamed a property of a class, and want to provide backward compatibility for a previously saved FastCoder file, you should implement a private setter method for the old property, which you can then map to wherever it should go in the new object structure. E.g. if the old property was called foo, add a private `-setFoo:` method. Alternatively, override the `-setValue:forUndefinedKey:` method to gracefully handle any unknown property.
 
If you want more precise control of the coding, such as using different names for keys, etc. then you can implement the NSCoding protocol. By default, if a class implements NSCoding, FastCoder will rely on the NSCoding methods to encode the object instead of automatically detecting the keys.


Bootstrapping
---------------------

Sometimes it is useful to be able to define an object graph by hand using a human-readable format such as JSON, but it's tedious and error-prone to write the recursive logic needed to convert the JSON dictionaries to the correct custom objects.

FastCoder has a neat feature that allows you to *bootstrap* a carefully structured JSON or Plist file into a native object graph via the FastCoding format. To define an object of class Foo using JSON, you would use the following structure:

    {
        "$class": "Foo",
        "someProperty1": 1
        "someProperty2": "Hello World!"
    }
    
You could then load this as an ordinary `NSDictionary` using `NSJSONSerialization`. But when you then convert this to data using FastCoder, it will detect the $class key and save this using the custom object record format instead of as a dictionary. When the resultant FastCoded data is decoded again, this will be initialized as an object of type Foo instead of a dictionary.

If you attempt to load the FastCoded file in an app that doesn't contain a class called Foo, the Foo object will just be loaded as an ordinary dictionary with a $class key, and then saved as a custom object again when the object is re-serialized. This means that it is possible to write applications and scripts that can process arbitrary FastCoded files without needing to know about or implement all of the classes used in the file (this is not possible using `NSCoding`, or at least would require a lot more work).


Aliases
---------------

Another limitation of ordinary Plist or JSON files versus an NSKeyedArchive or FastCoded file is that they don't support pointers or references. If you want multiple dictionary keys in a JSON file to point to the same object instance, there's no way to do that. FastCoding solves this problem using aliases.

As with the $class syntax used for bootstrapping custom object types, FastCoding treats a key with the name $alias as an internal file reference. The $alias value is a keypath relative to the root object in the file, used to specify an existing object instance. For example, see the following JSON:

    {
        "foo": {
            "baz": { "text": "Hello World" },
            "someProperty1": 1
        },
        "bar": {
            "baz": { "text": "Hello World" },
            "someProperty2": 2
        }
    }
    
Here, the objects foo and bar both contain an object baz. But if you want foo and bar to both reference the same baz instance, you would do that as follows:

    {
        "foo": {
            "baz": { "text": "Hello World" },
            "someProperty1": 1
        },
        "bar": {
            "baz": { "$alias": "foo.baz" }
            "someProperty2": 2
        }
    }
    
Note that the baz inside bar contains an alias to the baz inside foo. When saved as a FastCoded file and the loaded again, these will actually be the same object. It doesn't matter whether bar.baz aliases foo.baz or vice-versa; FastCoder aliasing supports forward references, and even circular references (where an object contains an alias to itself). The alias syntax works like a keypath, although, unlike regular keypaths, you can use numbers to represent array indices. For example, in the following code, foo points to the second object in the bar array, "Cruel":

    {
        "foo": { "$alias": "bar.1" },
        "bar": [ "Goodbye", "Cruel", "World" ]
    }


File structure
---------------------------

The FastArchive format is quite simple:

There is a header consisting of a 32-bit identifier, followed by two 16-bit version numbers (major and minor). The header is followed by three 32-bit integers representing the total number of unique objects, classes and strings encoded in the file, respectively (this is not the same as the number of chunks). These values can be used to set the capacities of the object caches in advance, which provides some performance benefit. If the object counts are not set (have a value of zero), the cache will be grown dynamically.

Following the header and object counts, there are a series of chunks. Each chunk consists of an 8-bit type identifier, followed by zero or more additional bytes of data, depending on the chunk type.

Commonly used types and values are represented by their own chunk in order to reduce file size and processing overhead. Compound or variable-length types such as strings or collections are encoded in the sequence of bytes that follow the chunk.
 
 
Migration from version 3.0
---------------------------
 
Unfortunately, version 3.0 files crashed on ARM7/ARM7s due to data alignment issues (this was fixed in version 3.0.1). If you saved data using that version and need to recover it, do the following:
 
Find the following macro in the FastCoder.m file:
 
    #define FC_ALIGN_INPUT(type, offset) { \
    unsigned long align = offset % sizeof(type); \
    if (align) offset += sizeof(type) - align; }
 
Modify it to this:
 
    #define FC_ALIGN_INPUT(type, offset)
 
Load the file and save it again. Now change the macro back again.

    
Release notes
------------------

Version 3.1.1

- Fixed crash when encoding classes where encodeWithCoder: contains an enumeration block

Version 3.1

- NSDecimalNumber is now supported (previously was encoded as NSNumber)
- Fixed bug with NSCoding support
- Fixed alignment issue when reading encoded NSDate objects (dates are hard, OK?)
- Fixed crash when using FastCoding with ARC (but you still shouldn't use ARC)

Version 3.0.2
 
- Fixed bug when encoding NSDate objects, due to alignment error
- Fixed bug where class and string counts were set incorrectly (minor performance impact)
 
Version 3.0.1
 
- Enabled data alignment to fix crash on ARM 32 devices
- Files created using version 3.0 cannot be loaded, there is a manual migration process if needed (see above)
 
Version 3.0

- Brand new file format that is both smaller and faster to encode/decode than before
- Added +propertyListWithData method for safely loading files from untrusted sources
- Parsing exceptions are now caught internally - in the event of an error, methods will return nil
- Fully backwards compatible with version 2.x files
- Fixed floating point precision bug
- Added support for CGVector type

Version 2.3
 
- FastCoding now includes compatibility for NSCoding, so any class that supports NSCoding will now be encoded by calling the NSCoding methods instead of using the FastCoding protocol (this is slightly slower, but more compatible)
- Fixed a bug in NSIndexSet decoding
- Fixed a minor memory leak in FCClassDefinition
- FastCoding 2.3 is fully backwards compatible (can read any version 2.x file). FastCoding 2.3 files can be read by a 2.2 implementation provided that they do not include NSCoded objects
 
Version 2.2
 
- Encoding NSIndexSet and NSMutableIndexSet is now supported
- Mac benchmark no longer relies on hardcoded path to json file
- FastCoding 2.2 is fully backwards compatible (can read version 2.0 or 2.1 files). FastCoding 2.2 files can be read by a 2.0 or 2.1 implementation provided that they do not include any of the new data types

Version 2.1.9

- Now imports CoreGraphics if not already included in .pch file
- Fixed some new warnings that cropped up in latest Xcode

Version 2.1.8

- Fixed memory leak when writing data

Version 2.1.7

- Fixed crash when saving

Version 2.1.6

- Fixed some conversion warnings when using ARC

Version 2.1.5

- Major speed improvements to object encoding (decoding speed is unaffected)
- FIxed some potential bugs cuased by empty strings or collections
- Fixed some minor memory leaks

Version 2.1.4

- Fixed bug when encoding NSURLs.

Version 2.1.3

- Fixed issue where properties from inherited classes would not be coded
- fastCodingKeys no longer includes properties with nonstandard ivar names (this brings the behaviour in line with the documentation)
- Fixed some compiler warnings

Version 2.1.2

- Fixed crash when loading bootstrapped objects
- Added benchmark for coding custom objects

Version 2.1.1

- Fixed a bug where multiple aliases to an object that returns a different instance from -awakeAfterFastCoding would not work correctly. This fix improves the common case, but there are still some caveats (see the documentation for the -awakeAfterFastCoding method for details).

Version 2.1

- Encoding NSURL and NSValue is now supported
- Immutable arrays, dictionaries and sets are no longer converted to mutable variants when encoded
- Added -classForFastCoding method (to avoid conflicts with NSCoding)
- Fixed a bug in object bootrapping when a $class dictionary does not contain a value for every property of the class that it represents
- FastCoding 2.1 is fully backwards compatible (can read version 2.0 files). FastCoding 2.1 files can be read by a 2.0 implementation provided that they do not include any of the new data types

Version 2.0.1

- Fixed bug in NSDate serialization

Version 2.0

- FastCoding 2.0 is not forwards or backwards compatible with version 1.0 files
- Added ability to automatically encode any object type
- Mutability of NSString and NSData objects is now preserved
- Added bootstrapping mechanism for creating native objects from plist/json
- Improved decoding performance

Version 1.1

- Improved security by throwing an exception if unexpected EOF is encountered
- Improved performance when using ARC (but don't use ARC)
- Refactored to use polymorphic style for serializing (cleaner code)
- Refactored to use function pointer array for parsing (slightly faster)
- Now complies with -Weverything warning level
- Addd Cocopods podspec file

Version 1.0.1

- Fixed bug in the aliasing logic

Version 1.0

- Initial release
