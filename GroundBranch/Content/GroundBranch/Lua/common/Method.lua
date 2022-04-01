local Method = {}

Method.__index = Method

---Extend a method
---@param obj table The table that contains the method
---@param name string Name of the method
---@param new_method function The new method.
---
---Extend a method
---@param obj table The table that contains the method
---@param name string Name of the method
---@param new_method function The new method.
---
---Example:
---
---     local Obj1 = {
---          z = 10
---     }
---     function Obj1:Foo(x, y)
---         return (x + y) * self.z
---     end
---
---     Obj1:Foo(1,2) -- result 30
---     Method.Extend(Obj1, 'Foo', function(self, super, x, y)
---         return super(x, y) / self.z
---     end)
---     Obj1:Foo(1,2) -- result 3
---
function Method.Extend(obj, name, new_method)
    local original = obj[name]
    obj[name] = function(selfRef, ...)
        local super = function(...)
            return original(selfRef, ...)
        end
        return new_method(selfRef, super, ...)
    end
end

return Method
