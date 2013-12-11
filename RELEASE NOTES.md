Version 2.0

- Added ability to automatically encode any object type
- Mutability of NSString and NSData objects is now preserved

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