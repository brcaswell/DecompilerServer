# GitHub Actions CI/CD Workflows

This directory contains comprehensive GitHub Actions workflows for the DecompilerServer project, designed to work within GitHub's free tier limits while providing thorough testing and quality assurance.

## Workflow Overview

### 1. Build and Test (`build-and-test.yml`)
**Triggers**: Push to main/develop/feature branches, PRs to main/develop  
**Purpose**: Core build validation and testing

**Jobs**:
- **build-and-test**: Full .NET 8 build, unit tests, formatting check
- **container-build**: Docker container build validation
- **cross-platform-build**: Multi-OS build verification (Ubuntu, Windows, macOS)

**Key Features**:
- Test result artifacts uploaded for analysis
- Code formatting verification with `dotnet format`
- MCP server container startup validation with JSON-RPC testing
- Cross-platform compatibility testing

### 2. File Watcher Integration Tests (`file-watcher-tests.yml`)
**Triggers**: Push to any feature branch (`feature/*`), PRs affecting file watcher components  
**Purpose**: Specialized testing for file watching functionality

**Jobs**:
- **file-watcher-tests**: End-to-end file watcher testing with real assemblies
- **podman-compatibility**: Podman-specific container testing

**Key Features**:
- Tests both executable and container file watching modes
- Podman compatibility validation with localhost/ image naming
- FileWatcherTest build configuration testing
- Container orchestration script validation
- MCP server request-response behavior testing

### 3. Release Build (`release.yml`)
**Triggers**: Git tags (v*), GitHub releases  
**Purpose**: Production release artifact creation

**Jobs**:
- **build-release**: Multi-platform executable builds (Linux x64, Windows x64)
- **build-container**: Release container image creation
- **attach-to-release**: Automatic artifact attachment to GitHub releases

**Key Features**:
- Self-contained and framework-dependent build options
- Automated artifact creation and upload
- Release asset attachment for easy distribution

### 4. Code Quality (`code-quality.yml`)
**Triggers**: Push/PR to main/develop, weekly schedule (Sundays 2 AM UTC)  
**Purpose**: Code quality monitoring and security analysis

**Jobs**:
- **code-analysis**: Code formatting, security scanning, test coverage
- **dependency-check**: NuGet package vulnerability and deprecation analysis
- **documentation-check**: Documentation structure validation

**Key Features**:
- Weekly automated quality checks
- Test coverage reporting with HTML artifacts
- Security vulnerability detection
- Documentation structure validation

## Free Tier Optimization

All workflows are designed to work within GitHub's free tier limits:

- **Concurrent Job Limits**: Workflows use job dependencies (`needs:`) to manage concurrency
- **Build Time Optimization**: Efficient caching, targeted test runs, matrix strategies
- **Resource Management**: Appropriate runner selection, cleanup steps
- **Artifact Management**: Selective artifact upload, reasonable retention periods

## Usage Examples

### Development Workflow
1. **Feature Development**: Push to `feature/*` branches triggers both build-and-test and file-watcher-tests
2. **Pull Request**: Creates full validation across multiple jobs
3. **Main/Develop**: Full quality checks including scheduled analysis

### Release Process
1. **Create Git Tag**: `git tag v1.0.0 && git push origin v1.0.0`
2. **Automatic Build**: Release workflow creates all artifacts
3. **GitHub Release**: Artifacts automatically attached to release

### Quality Monitoring
- **Weekly Reports**: Scheduled runs provide regular quality insights
- **Coverage Reports**: Available as workflow artifacts
- **Security Updates**: Automated vulnerability detection

## Customization

### Adding New Workflows
1. Create new `.yml` files in `.github/workflows/`
2. Follow existing patterns for consistency
3. Consider free tier limits when adding jobs
4. Test with draft PRs before merging

### Modifying Existing Workflows
- Update trigger conditions in `on:` sections
- Modify job matrices for different platforms/configurations
- Adjust artifact retention policies as needed
- Ensure job dependencies remain logical

### Environment Variables
Key environment variables used across workflows:
- `DOTNET_VERSION`: .NET version (8.0.x)
- `BUILD_CONFIGURATION`: Build configuration (Release)
- `TEST_FILTER`: Test filtering expressions

## Troubleshooting

### Common Issues
1. **Build Failures**: Check .NET version compatibility, restore dependencies
2. **Test Timeouts**: Adjust timeout values in workflow files
3. **Container Issues**: Verify Dockerfile and image naming conventions
4. **Artifact Upload Failures**: Check file paths and artifact size limits

### Debugging Steps
1. Review workflow run logs in GitHub Actions tab
2. Check artifact downloads for detailed reports
3. Validate local builds match CI environment
4. Use workflow dispatch for manual testing

## Integration with Fork Repositories

These workflows are designed to work seamlessly in fork repositories:
- No external services or secrets required
- Self-contained testing with TestLibrary
- GitHub-hosted runners only
- Automatic artifact management

Perfect for contributors working on forks while maintaining full CI/CD capabilities.