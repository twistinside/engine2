import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SignpostedUpdateMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("@SignpostedUpdate can only be attached to a function")
        }

        guard function.name.text == "update" else {
            throw MacroExpansionErrorMessage("@SignpostedUpdate can only be attached to a function named update")
        }

        guard let body = function.body else {
            throw MacroExpansionErrorMessage("@SignpostedUpdate requires a function body")
        }

        guard
            let arguments = node.arguments?.as(LabeledExprListSyntax.self),
            arguments.count == 1,
            let signposterArgument = arguments.first,
            signposterArgument.label?.text == "signposter"
        else {
            throw MacroExpansionErrorMessage("@SignpostedUpdate requires a signposter: argument")
        }

        let signposterExpression = signposterArgument.expression
        let intervalName = try signpostName(in: context)

        return try [
            """
            let __signposter = \(signposterExpression)
            """,
            """
            let __state = __signposter.beginInterval("\(raw: intervalName)")
            """,
            """
            defer {
                __signposter.endInterval("\(raw: intervalName)", __state)
            }
            """
        ] + body.statements.map(CodeBlockItemSyntax.init)
    }

    private static func signpostName(in context: some MacroExpansionContext) throws -> String {
        guard let typeName = enclosingTypeName(in: context.lexicalContext) else {
            throw MacroExpansionErrorMessage(
                "@SignpostedUpdate requires update to be declared inside a type"
            )
        }

        return "\(typeName).update"
    }

    private static func enclosingTypeName(in lexicalContext: [Syntax]) -> String? {
        for syntax in lexicalContext {
            if let classDecl = syntax.as(ClassDeclSyntax.self) {
                return classDecl.name.text
            }

            if let structDecl = syntax.as(StructDeclSyntax.self) {
                return structDecl.name.text
            }

            if let actorDecl = syntax.as(ActorDeclSyntax.self) {
                return actorDecl.name.text
            }

            if let enumDecl = syntax.as(EnumDeclSyntax.self) {
                return enumDecl.name.text
            }

            if let extensionDecl = syntax.as(ExtensionDeclSyntax.self) {
                return extensionDecl.extendedType.description
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }
}

@main
struct Engine2MacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SignpostedUpdateMacro.self,
    ]
}
