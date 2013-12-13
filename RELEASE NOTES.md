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