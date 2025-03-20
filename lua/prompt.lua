Person = {}
Person.__index = Person

function Person.new(name)
    local self = setmetatable({}, Person)
    self.name = name
    self.hobby = "programming"
    return self
end

function Person:hello()
    print("Hello, my name is " .. self.name .. ", and my hobby is " .. self.hobby)
end

function Person:set_hobby(hobby)
    self.hobby = hobby
end

local alice = Person.new("Alice")
local bob = Person.new("Bob")

alice:hello()
bob:hello()

print("Changind hobbies...")
alice:set_hobby("reading")
bob:set_hobby("gardening")

alice:hello()
bob:hello()
