import PackagePlugin

@main
struct MyPlugin: BuildToolPlugin {
    
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target.sourceModule else { return [] }
        let inputFiles = target.sourceFiles(withSuffix: "yml")
        let outputPath = context.pluginWorkDirectoryURL.appending(path: "GeneratedSteps").appendingPathExtension("swift")
        return [.buildCommand(displayName: "Create Step Definitions",
                             executable: try context.tool(named: "RunGenSteps").url,
                              arguments: inputFiles.map(\.url.absoluteString) + [outputPath.absoluteString],
                             environment: [:],
                             inputFiles: inputFiles.map(\.url),
                             outputFiles: [outputPath.absoluteURL])]
    }
}
