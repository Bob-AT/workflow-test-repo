local test = UnitTest or error('Run with TestSuite.lua')

--
-- Example tests
--
test('Trivial test #1', 2999 < 3)

test('Trivial test #2', function()
    assert(2 < 3)
    assert(3 > 2)
end)

test('Foo', function()
    print('Hello')
    test.AssertStdout('Hello\n')
end)

test('Foo', function()
    print('Hello')
    print('World')
    test.AssertStdout({ 'Hello', 'World' })
end)
