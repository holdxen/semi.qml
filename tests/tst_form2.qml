import QtQuick
import QtTest
import Semi

TestCase {
    id: testCase

    name: "Form"
    when: windowShown
    width: 400
    height: 400

    function init() {
        testCase.visible = true
        Theme.reset()
        Theme.mode = Theme.Light
    }

    function makeForm() {
        return Qt.createQmlObject("import QtQuick; import Semi; Form { }", testCase, "f")
    }

    function test_registerAndCheckRequired() {
        const f = makeForm()
        f.registerField("name", { rules: [], label: "姓名", required: true })

        f.setValue("name", "张三")
        compare(f.checkField("name"), "")

        f.setValue("name", "")
        verify(f.checkField("name") !== "")
        f.destroy()
    }

    function test_minLengthRule() {
        const f = makeForm()
        f.registerField("pwd", { rules: [{ minLength: 8, message: "密码太短" }], required: false })

        f.setValue("pwd", "abc")
        compare(f.checkField("pwd"), "密码太短")

        f.setValue("pwd", "abcdefgh")
        compare(f.checkField("pwd"), "")
        f.destroy()
    }

    function test_patternRule() {
        const f = makeForm()
        f.registerField("mail", { rules: [
            { pattern: "^[^@]+@[^@]+\\.[^@]+$", message: "邮箱格式不正确" }
        ], required: false })

        f.setValue("mail", "not-an-email")
        compare(f.checkField("mail"), "邮箱格式不正确")

        f.setValue("mail", "a@b.com")
        compare(f.checkField("mail"), "")
        f.destroy()
    }

    function test_customValidator() {
        const f = makeForm()
        f.registerField("age", { rules: [
            { validator: (rule, v) => Number(v) >= 18 ? true : "未满 18 岁" }
        ], required: false })

        f.setValue("age", "16")
        compare(f.checkField("age"), "未满 18 岁")

        f.setValue("age", "20")
        compare(f.checkField("age"), "")
        f.destroy()
    }

    function test_validateCollectsAllErrors() {
        const f = makeForm()
        f.registerField("a", { rules: [], required: true })
        f.registerField("b", { rules: [], required: true })

        f.setValue("a", "")
        f.setValue("b", "")
        compare(f.validate(), false)
        verify(f.errorOf("a") !== "")
        verify(f.errorOf("b") !== "")

        f.setValue("a", "x")
        f.setValue("b", "y")
        compare(f.validate(), true)
        compare(f.errorOf("a"), "")
        f.destroy()
    }

    function test_setValueRevalidatesWhenErrored() {
        const f = makeForm()
        f.registerField("a", { rules: [], required: true })
        f.setValue("a", "")
        f.validate()
        verify(f.errorOf("a") !== "")

        // 出错后再改动会自动重新校验并清掉错误
        f.setValue("a", "填上了")
        compare(f.errorOf("a"), "")
        f.destroy()
    }

    function test_resetClearsState() {
        const f = makeForm()
        f.registerField("a", { rules: [], required: true })
        f.setValue("a", "x")
        f.validate()

        f.reset()
        compare(f.errorOf("a"), "")
        compare(f.values.a, undefined)
        f.destroy()
    }
}
