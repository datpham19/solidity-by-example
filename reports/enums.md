## Use cases
- Optional/nullable data types.
- Variant data types.
- Flag with extra information needed only in some cases (or different in different cases).
- Modeling states in a state machine where each state can have some data associated with it.
- List of operations for batch processing, where each operation can have its own arguments.
- Alternative to function overloading that allows avoiding combinatorial explosion when there are multiple parameters that need variants.
- Nested data structures with heterogenous nodes.

## Syntax and semantics

### Definition
Plain enum
```solidity
enum Choice {A, B, C}
```

Enum carrying data (with empty variants)
```solidity
interface LocationSource {}

struct MapCoordinates {
    int8 latitude;
    int16 longitude;
}

enum Location {
    Unknown,
    NorthPole,
    SouthPole,
    Point(int8 latitude, int16 longitude),
    Point2(MapCoordinates point),
    Named(string name),
    Random(Location[] choices),
    Dynamic(function() returns (Location memory) generator)
    Auto(LocationSource[] locationSources, MapCoordinates default),
}
```

Enum carrying data (without empty variants)
```solidity
enum Commitment {
    Hidden(bytes32 hash),
    Revealed(uint value)
}
```

Points of note:
- Empty enums are not allowed.
- A variant can have a tuple associated with it.
- If the variant tuple is empty, the parenthesis must be omitted.
- Tuple members must be named.
- Recursive use of the enum within its own variants follows the same rules structs currently do - it is allowed only as a part of dynamic arrays and in function parameters.
- Variant names (e.g. `Location.Auto`) are not types. They cannot be used in variable declarations.
    - We could allow `type(Location.Auto)` in contexts where `type()` is already allowed.

### Usage
#### Summary
The examples below go into more detail but first, here's a distilled summary:

1) **Comparisons**: Variant constants (like `Location.Point`) can be compared with other variant constants of the same enum (so same as enum values now). The new thing is that enum variables/instances can be compared with enum constants too.
2) **Conversions**: Variant constants can be (explicitly) converted to integers for compatibility with existing enums.
3) **Variable declaration**: Enums carrying data are initialized with default values just like you would expect enums/structs. Variables can be assigned a value at the point of declaration.
4) **Assignment**: Assignments work like for structs. When creating an instance, a constructor needs to be called so parentheses are mandatory even if the variant has no members (e.g. `Location.Unknown()`).
5) **Member assignment**: Variant name is required when selecting a member (e.g. `location.Point.latitude)`.
6) **Member access**: Members must have names and can be accessed by name. Indexed access is not allowed for tuples anyway.
7) **Variant tuple assignment**: You can use variant name to refer to its tuple as a whole and this tuple can be used anywhere where tuples can be used now. It can also be assigned in context where member-wise copy is expected today. The assignment allows implicit conversions between members (because that's how tuples currently work).
8) **Variant tuple access**: Destructuring works just like for ordinary tuples. Including implicit conversions.
9) **Variant tuples vs structs and enums**: Implicit conversions between variant tuples and whole enums are forbidden. Same for variant tuples and enums (though we might want to enable those if we implement #9599).
10) **`delete`**: You can use `delete` like with structs. Both on the whole enum and on its variant tuples and members.

#### Typical use example
First, a general example of how this would look like used in practice. Later sections focus on specific aspects in detail.

```solidity
function resolveLocation(Location memory _location) pure returns (MapCoordinates memory) {
    if (_location == Location.Unknown)
        revert("Location not specified");
    else if (_location == Location.Point)
        return MapCoordinates(_location.Point.latitude, _location.Point.longitude);
    else if (_location == Location.Point2)
        return _location.Point2.point;
    else if (_location == Location.Named)
        return resolveLocation(namedLocations(_location.Named.name));
    else if (_location == Location.Random) {
        require(Location.Random.choices.length >= 10);
        return resolveLocation(_location.Random.choices[4]); // Chosen by fair dice roll. Guaranteed to be random.
    }
    else if (_location == Location.Dynamic) {
        return resolveLocation(_location.Dynamic.generator());
    }
    else if (_location == Location.Auto) {
        for (uint i = 0; i < _location.Auto.locationSources; ++i) {
            GeoInfo memory geoInfo = _location.Auto.locationSources[i].locate();
            if (geoInfo.found)
                return MapCoordinates(geoInfo.latitude, geoInfo.longitude);
        }
        return _location.Auto.default;
    }
    else {
        assert(_location == Location.NorthPole || _location == Location.SouthPole);
        return MapCoordinates(_location == Location.NorthPole ? 90 : -90, 0);
    }
}
```

#### Comparisons
```solidity
function f() {
    Location memory location1 = Location.Point(42, 42);
    Location memory location2 = Location.Point2(MapCoordinates(42, 42));

    // Variant constants can be compared for equality
    assert(Location.Point == Location.Point);
    assert(Location.Point != Location.Point2);

    // Variant constants can be compared for equality with enum instances
    assert(Location.Point(0, 0) == Location.Point);
    assert(Location.Point(0, 0) != Location.Unknown);

    // Variant constants of different types cannot be compared
    //assert(Location.Point == Commitment.Revealed); // ERROR
    //assert(location1 == Commitment.Revealed);      // ERROR

    // Variant tuples cannot be compared with variant constants
    //assert(location1.Point == Location.Point); // ERROR

    // Variant tuples cannot be compared because tuple comparisons are not allowed in general
    //assert(location1.Point == location2.Point2);       // ERROR
    //assert(location1.Point == location2.Point2.point); // ERROR
    //assert(location1.Point == MapCoordinates(42, 42)); // ERROR
}
```

#### Conversions
```solidity
function f() {
    // Variant constants can be converted to integers but instances cannot
    uint8 locationType1 = uint8(Location.NorthPole);
    uint8 locationType2 = uint8(Location.Point);
    //uint8 locationType1 = uint8(Location.NorthPole()); // ERROR
    //uint8 locationType2 = uint8(Location.Point(0, 0)); // ERROR

    // Enums and variant tuples cannot be directly converted to the types they contain
    Location memory location = Location.Named("Alaska");
    //string name = string(location.Named); // ERROR
    //string name = string(location);       // ERROR
}
```

#### Variable declaration
```solidity
function f() {
    // Default value follows the rules for enums.
    Location memory location1;
    assert(location == Location.Unknown);

    // The associated fields are initialized like in structs.
    Commitment memory commitment;
    assert(commitment == Commitment.Hidden);
    assert(commitment.Hidden.hash == 0);

    // The initial value can be specified
    Location memory location2 = Location.Point(42, 42);
}
```

#### Assignment
```solidity
contract C {
    Location sLocation1;
    Location sLocation2;

    function f() {
        Location memory mLocation1;
        Location memory mLocation2;

        // Enums carrying data are reference types and initialization follows the rules for structs.
        // Parentheses are required even if the chosen variant is empty.
        mLocation1 = Location.NorthPole();
        mLocation2 = Location.Point(42, 42);
        //mLocation1 = Location.NorthPole;     // ERROR
        //mLocation2 = Location.Point;         // ERROR

        // Assignment between memory objects just copies the reference.
        mLocation1 = mLocation2;
        mLocation2.latitude = 0;
        assert(mLocation1.latitude == 0);

        // Assignment from memory to storage is a member-wise copy
        sLocation1 = mLocation2;
        sLocation1.longitude = 0;
        assert(mLocation2.longitude == 42);

        // Assignment within storage is a member-wise copy too
        sLocation1 = Location.Point(0, 0);
        sLocation2 = sLocation1;
        sLocation1 = Location.Point(42, 42);
        assert(mLocation2.longitude == 0);

        // Assignment from storage to memory is not allowed for structs so it won't work for enums carrying data either.
        //mLocation2 = sLocation; // ERROR
    }
}
```

#### Member assignment
```solidity
function f() {
    Location memory location;

    location.Point2.point = MapCoordinates(42, 42);
    location.Point2.point.latitude = 42;
    location.Point2.point.longitude = 42;
}
```

#### Member access
```solidity
function f() {
    Location memory location = Location.Point2(MapCoordinates(42, 42));

    int8 latitude = location.Point2.point.latitude;
    int16 longitude = location.Point2.point.longitude;
    MapCoordinates memory coordinates = location.Point2.point;

    // Indexed access for tuples is currently not allowed so it won't work for variant tuples either.
    //MapCoordinates memory coordinates = location.Point2[0]; // ERROR
```

#### Variant tuple assignment
```solidity
enum ExactLocation {
    Point(int8 latitude, int16 longitude)
}

enum ExactLocation256 {
    Point(int latitude, int longitude)
}

contract C {
    Location sLocation;
    ExactLocation sExactLocation;
    ExactLocation256 sExactLocation256;

    function get() public returns (uint8, uint16) {}

    function f() public {
        sLocation = Location.Point(0, 0);

        Location memory mLocation = Location.Point(0, 0);
        ExactLocation memory mExactLocation = ExactLocation.Point(0, 0);

        // Tuples are not reference types so assignment should work only in contexts where currently
        // member-wise copy would be expected for types like structs and arrays.

        // Struct assignments within memory currently work on references.
        //mLocation.Point = mLocation.Point; // ERROR

        // Member-wise copy from storage to memory is currently disallowed for structs.
        //mLocation.Point = sLocation.Point; // ERROR

        // Copying to storage works
        sLocation.Point = mLocation.Point;
        sLocation.Point = sLocation.Point;

        // Tuples returned from functions
        mLocation.Point = get();
        sLocation.Point = get();

        // The enum type does not need to match as long as types of members do
        sExactLocation.Point = mLocation.Point;

        // Implicit conversions of member types are allowed just like for normal tuples
        sExactLocation256.Point = mLocation.Point;
        sExactLocation256.Point = get();
    }
}
```

#### Variant tuple access
```solidity
contract C {
    Location sLocation;

    function get() public returns (uint8, uint16) {
        return Location.Point(42, 42).Point;
    }

    function f() public {
        sLocation = Location.Point(0, 0);

        Location memory mLocation = Location.Point(0, 0);

        // Destructuring works just like it does currently for functions
        (int8 latitude1, int16 longitude1) = mLocation.Point;
        (int8 latitude2, int16 longitude2) = sLocation.Point;
        (int8 latitude3, int16 longitude3) = get();

        // Implicit conversions of member types are allowed
        (int latitude4, int longitude4) = mLocation.Point;
        (int latitude5, int longitude5) = sLocation.Point;
        (int latitude6, int longitude6) = get();
    }
}
```

#### Variant tuples vs structs and enums
```solidity
struct ExactLocationStruct {
    int8 latitude;
    int16 longitude;
}

function f() {
    Location memory location = Location.Point(0, 0);
    ExactLocationStruct memory exactLocationStruct = ExactLocationStruct(42, 42);

    // No implicit conversion between variant tuples and whole enums
    //location = location.Point; // ERROR
    //location.Point = location; // ERROR

    // No implicit conversion between variant tuples and structs (unless we implement #9599)
    //location.Point = exactLocationStruct; // ERROR
    //exactLocationStruct = location.Point; // ERROR
}
```

#### `delete`
```solidity
function f() {
    Location memory location = Location.Point(42, 42);

    delete location.Point;
    assert(location == Location.Point)

    // You can't delete a variant that is not currently selected.
    //delete location.Auto; // ERROR

    delete location;
    assert(location == Location.Unknown)
}
```

## Encoding
### General
Plain enums and enums carrying data share a lot of syntax but are internally completely different types.
- Plain enums are value types, with encoding equivalent to the integer type used internally to represent them.
- Enums carrying data are reference types.
    - They're considered statically sized unless at least one variant contains at least one dynamically sized member.
    - They cannot be stored on the stack.
    - It's possible to have a reference to such an enum.

### Example enum definition
Layout examples used below will refer to the following example definition:
```solidity
struct S {
    function() external f;
    uint x;
}

enum E {
    A(bytes4 a1, address a2, uint a3),
    B(bytes4 b1, address b2, S b3, bytes16 b4),
    C(int32[] c1),
    D(uint128 d1, uint16[2] c2)
}
```

### The issue with overlapping values
Since Solidity does not allow creating and destroying type instances at arbitrary locations in storage and memory, enums carrying data would be the first mechanism allowing the type associated with a given location in memory/storage to change at runtime. That is - if we allow the variants to overlap.

This beaks type safety when we can have multiple references pointing at the same location at the same time. If the selected variant changes, old references don't get updated automatically and could allow referring to the new variant using the types from the old one that no longer exists.

```solidity
struct Functor {
    function() f;
}

enum IntOrFunctor {
    I(uint value),
    F(Functor functor)
}

contract C {
    IntOrFunctor iof;

    function doSomething() {}

    function f() {
        iof = IntOrFunctor.F(Functor(doSomething));
        Functor storage functorPtr = iof.F.functor;

        iof = IntOrFunctor.I(42);
        functorPtr.f() // What does it call?
    }
}
```

### Layout in storage
Enums in storage are more similar to structs than to plain enums:
- Their members are packed.
- Just like a struct, an enum with data always starts a new slot.

Below are four out of many possible storage layouts. (A) is provided mainly for illustration.

#### Layout A (fully overlapping)
In this layout every variant has encoding identical to a struct containing plain enum followed by all the other variant members.

```
        |================+================+================+================+     +================+
Slot    | N              | N + 1          | N + 2          | N + 3          | ... | keccak(N + 1)  | ...
        |================+================+================+================+     +================+
E.A     | 0, a1, a2, a3  |                |                |                | ... |                | ...
        |----------------+----------------+----------------+----------------+     +----------------+
E.B     | 1, b1, b2      | b3.f           | b3.x           | b4             | ... |                | ...
        |----------------+----------------+----------------+----------------+     +----------------+
E.C     | 2              | 1              |                |                | ... | c1[0]          | ...
        |----------------+----------------+----------------+----------------+     +----------------+
E.D     | 3, d1          | d2[0], d2[1]   |                |                | ... |                | ...
        |----------------+----------------+----------------+----------------+     +----------------+
```

**Pros**:
- Variant selector does not require an extra slot if the first member of a variant is of a value type and does not occupy the full slot.
- Is only as long as the longest variant.
- Relative positions of all variants are constant.
- It's possible to add new members to variants without shifting the locations of other variants and making the change backwards-incompatible.

**Cons**:
- Does not solve the issue with references to overlapping variants.

#### Layout B (fully non-overlapping)
In this layout the variant selector is stored in the first slot. It's followed by all variants, laid out one after another, without overlaps. As an optimization to reduce storage use the first members of the first variant could be stored together with variant selector as long as they are of value types and don't occupy a whole slot.

```
        |================+================+================+================+================+================+================+================+     +================+
Slot    | N              | N + 1          | N + 2          | N + 3          | N + 4          | N + 5          | N + 6          | N + 7          | ... | keccak(N + 5)  | ...
        |================+================+================+================+================+================+================+================+     +================+
E.A     | 0, a1, a2, a3  |                |                |                |                |                |                |                | ... |                | ...
        |----------------+----------------+----------------+----------------+----------------+----------------+----------------+----------------+     +----------------+
E.B     | 1              | b1, b2         | b3.f           | b3.x           | b4             |                |                |                | ... |                | ...
        |----------------+----------------+----------------+----------------+----------------+----------------+----------------+----------------+     +----------------+
E.C     | 2              |                |                |                |                | 1              |                |                | ... | c1[0]          | ...
        |----------------+----------------+----------------+----------------+----------------+----------------+----------------+----------------+     +----------------+
E.D     | 3              |                |                |                |                |                | d1             | d2[0], d2[1]   | ... |                | ...
        |----------------+----------------+----------------+----------------+----------------+----------------+----------------+----------------+     +----------------+
```

**Pros**:
- No overlaps, no problems.
- Simpler calculation to find the slot that contains data for each variant.
- Relative positions of all variants are constant.
- Order of variants or members in a variant does not matter (except for the first variant if we apply the optimization suggested above).

**Cons**:
- Always requires an extra slot for the variant selector.
- Takes up as much storage as all variants taken together (though most of that space is unused so it does not incur a cost). This would increase the risk of collisions if large sparse arrays were used in multiple variants (related to #9955).
- Only the last variant is easy to extend. Adding a new member in any other variant makes the layout backwards-incompatible.

#### Layout C (overlapping prefixes)
In this layout the members of each variant are divided into two, contiguous groups:
- **Body**: the first member of reference/mapping type in this variant and all members after it.
- **Prefix**: all members before the body.

For example in `X(uint, address, struct, bytes, uint, uint[2], bytes8)` the prefix would consist of `uint, address` and `struct, bytes, uint, uint[2], bytes8` would be the body.

The space occupied by any enum instance is equivalent to a series of structs where the first one contains the variant selector and the members of the biggest prefix and subsequent structs contain members of the bodies. For a given variant only the prefix struct and its body struct actually store data. The rest is not zeroed until another variant gets selected.

```
        |================+================+================+================+================+================+     +================+
Slot    | N              | N + 1          | N + 2          | N + 3          | N + 4          | N + 5          | ... | keccak(N + 4)  | ...
        |================+================+================+================+================+================+     +================+
E.A     | 0, a1, a2, a3  |                |                |                |                |                | ... |                | ...
        |----------------+----------------+----------------+----------------+----------------+----------------+     +----------------+
E.B     | 1, b1, b2      | b3.f           | b3.x           | b4             |                |                | ... |                | ...
        |----------------+----------------+----------------+----------------+----------------+----------------+     +----------------+
E.C     | 2              |                |                |                | 1              |                | ... | c1[0]          | ...
        |----------------+----------------+----------------+----------------+----------------+----------------+     +----------------+
E.D     | 3, d1          |                |                |                |                | d2[0], d2[1]   | ... |                | ...
        |----------------+----------------+----------------+----------------+----------------+----------------+     +----------------+
        ^                ^                                                  ^                ^                ^
        |                |                                                  |                |                |
        |   PREFIXES     |                   BODY OF E.B                    |  BODY OF E.C   |  BODY OF E.D   |
```

**Pros**:
- Equivalent to a fully ovelapping layout in the optimistic case where all variants contain only non-reference/mapping types.
- User can minimize the number of overlapping members by rearranging them.
- Relative positions of all variants are constant.
- If variants don't contain reference/mapping types, it's possible to add new members in a backwards-compatible way, without shifting the locations of other variants.

**Cons**:
- Equivalent to a fully non-overlapping layout in the worst case where the first members of all variants are of reference/mapping types.
- More complex calculation to find the slots than in layouts A and B.
- User has to care about the order or members in each variant to get best results.

#### Layout D (hash-based)
This layout would be equivalent to a one-key mapping from a plain enum type to a struct containing variant members. Only one struct is actually allocated at any given time. The empty slot of the mapping is used to store the variant selector.

```
        |================+     +================+     +================+================+================+================+     +================+     +================+================+     +======================+
Slot    | N              | ... | keccak(A . N)  | ... | keccak(B . N)  | keccak(B . N)+1| keccak(B . N)+2| keccak(B . N)+3| ... | keccak(C . N)  | ... | keccak(D . N)  | keccak(D . N)+1| ... | keccak(keccak(C . N))| ...
        |================+     +================+     +================+================+================+================+     +================+     +================+================+     +======================+
E.A     | 0              | ... | a1, a2, a3     | ... |                |                |                |                | ... |                | ... |                |                | ... |                      | ...
        |----------------+     +----------------+     +----------------+----------------+----------------+----------------+     +----------------+     +----------------+----------------+     +----------------------+
E.B     | 1              | ... |                | ... | b1, b2         | b3.f           | b3.x           | b4             | ... |                | ... |                |                | ... |                      | ...
        |----------------+     +----------------+     +----------------+----------------+----------------+----------------+     +----------------+     +----------------+----------------+     +----------------------+
E.C     | 2              | ... |                | ... |                |                |                |                | ... | 1              | ... |                |                | ... | c1[0]                | ...
        |----------------+     +----------------+     +----------------+----------------+----------------+----------------+     +----------------+     +----------------+----------------+     +----------------------+
E.D     | 3              | ... |                | ... |                |                |                |                | ... |                | ... | d1             | d2[0], d2[1]   | ... |                      | ...
        |----------------+     +----------------+     +----------------+----------------+----------------+----------------+     +----------------+     +----------------+----------------+     +----------------------+
```

**Pros**:
- No overlaps, no problems.
- Conceptually very simple and elegant.
- Order of variants or members in a variant does not matter.
- It's possible to add new members to variants without shifting the locations of other variants and making the change backwards-incompatible.

**Cons**:
- Always requires an extra slot for the variant selector.
- Takes up as much storage as all variants taken together (though most of that space is unused so it does not incur a cost). This would increase the risk of collisions if large sparse arrays were used in multiple variants (related to #9955).
- Adds a level of indirection. For example the location of the data part of a dynamic array cannot be computed at compilation time even if the array is not nested in another dynamically-sized type.
- This is not viable in memory so memory and storage layouts for such enums would end up being wildly different.

### Layout in memory
In memory the overlap problem is still relevant but minimizing the amount of space not so much so we can go for fully non-overlapping layout.

The layout is equivalent to a plain enum followed by a series of structs representing variants.

```
        |========+========+========+========+========+========+========+========+========+========+========+========+========+========+========+========+========+
Slot    | N      | N+1    | N+2    | N+3    | N+4    | N+5    | N+6    | N+7    | N+8    | N+9    |  N+10  | N+11   | N+12   | N+13   | N+14   |  N+15  |  N+16  | ...
        |========+========+========+========+========+========+========+========+========+========+========+========+========+========+========+========+========+
E.A     | 0      | a1     | a2     | a3     |        |        |        |        |        |        |        |        |        |        |        |        |        | ...
        |--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+
E.B     | 1      |        |        |        | b1     | b2     | b3 ptr | b4     |        |        |        | b3.f   | b3.x   |        |        |        |        | ...
        |--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+
E.C     | 2      |        |        |        |        |        |        |        | c1 ptr |        |        |        |        | 1      | c1[0]  |        |        | ...
        |--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+
E.D     | 3      |        |        |        |        |        |        |        |        | d1     | d2 ptr |        |        |        |        | d2[0]  | d2[1]  | ...
        |--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+--------+
```

### ABI encoding
ABI encoding for enums carrying data is similar to the current encoding of structs/tuples except that:
- each variant is encoded as a separate type,
- head of each variant is padded to the same size, so that the types are compatible with each other,

If any variant contains a member of a dynamic type, the whole enum is considered dynamic but static variants are still encoded in a static way (everything in the head, empty tail).

Note that because of the padding, encoding of a variant that has no members is not identical to the encoding of a plain enum value. Also, adding/removing variants may affect the head size.

#### Formal definition
More formally, the current [Contract ABI Specification](https://solidity.readthedocs.io/en/latest/abi-spec.html) would be extended in the following way:

For ABI value `X` of type
```
enum E {
    V1(T1_1, ..., T1_k1),
    ...
    Vn(Tn_1, ..., Tn_kn)
}
```
for `k1, k2, ..., kn >= 0`, `n > 0` and any types `T1_1`, ..., `T1_k1`, ..., `Tn_1`, ..., `Tn_kn` we define `enc(X)` as:

```
enc(X) = enc(V) head((X(1)) ... head((X(p)) padding tail((X(1)) ... tail((X(p))
```

where
- `X` is enum value representing one specific variant,
- `V` is the plain enum value corresponding to the selected variant,
- `p` is the number of members of variant `V`,
- `X(i)` is the value of i-th member of the selected variant,
- `padding` consists of exactly `max(len(head(T1_1) ... head(T1_k1)), ..., len(head(Tn_1) ... head(Tn_kn))) - len(head(X(1)) ... head(X(k)))` unused bytes, where `len(head(T))` is the head size of an instance of type T,
- `head(X(i))` and `tail(X(i))` are defined just like for tuples.

#### Example
```
        |========+========+========+========+========+========+========+========|
Slot    | N      | N+1    | N+2    | N+3    | N+4    | N+5    | N+6    | N+7    |
        |========+========+========+========+========+========+========+========|
E.A     | 0      | a1     | a2     | a3     | 0      | 0      |        |        |
        |--------+--------+--------+--------+--------+--------+--------+--------|
E.B     | 1      | b1     | b2     | b3.f   | b3.x   | b4     |        |        |
        |--------+--------+--------+--------+--------+--------+--------+--------|
E.C     | 2      | 192    | 0      | 0      | 0      | 0      | 1      | c1[0]  |
        |--------+--------+--------+--------+--------+--------+--------+--------|
E.D     | 3      | d1     | d2[0]  | d2[1]  | 0      | 0      |        |        |
        |--------+--------+--------+--------+--------+--------+--------+--------|
        ^                                                     ^                 ^
        |                                                     |                 |
        |                        HEADS                        |      TAILS      |
```