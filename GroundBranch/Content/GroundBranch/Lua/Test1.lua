local MyPoint = {X=1, Y=2}
setmetatable(MyPoint, {_tostring = function(obj)
    return string.format("Point(X=%q,Y=%q)", obj.X, obj.Y)
end
})

print("----------------")
print(MyPoint, 1)
print(tostring(MyPoint), 2)

