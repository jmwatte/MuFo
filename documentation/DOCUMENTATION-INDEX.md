# MuFo Documentation Index

## Quick Start
- 📋 **[Quick Reference](MANUAL-WORKFLOW-QUICKREF.md)** - TL;DR commands and examples
- 📖 **[Complete Workflow Guide](MANUAL-WORKFLOW-GUIDE.md)** - Comprehensive manual workflow documentation

## Project Status
- 🗺️ **[Current Roadmap](CURRENT-ROADMAP.md)** - Current priorities and next steps (updated Sept 22, 2025)
- ✅ **[Implementation Status](IMPLEMENTATION-STATUS.md)** - Complete feature implementation tracker
- 📊 **[Flow Diagram](flow-mufo.md)** - Mermaid flowchart of execution logic

## Manual Override System (NEW)
- 📖 **[Manual Workflow Guide](MANUAL-WORKFLOW-GUIDE.md)** - Complete documentation for manual track mapping
- 📋 **[Quick Reference](MANUAL-WORKFLOW-QUICKREF.md)** - Fast reference for common commands
- 🧪 **[Test Suite](../tests/test-comprehensive.ps1)** - Comprehensive validation tests

## Development Resources
- 🤖 **[AI Coding Instructions](../.github/copilot-instructions.md)** - Guidelines for AI agents working on MuFo
- 📚 **[Parameter Reference](PARAMETER-REFERENCE.md)** - Complete parameter documentation
- ⚡ **[Performance Guide](PERFORMANCE-GUIDE.md)** - Optimization tips and benchmarks

## Archive
- 📁 **[archive/](archive/)** - Historical implementation documents and planning files

## Getting Help

### Command Help
```powershell
# Main function help
Get-Help Invoke-MuFo -Full

# Manual workflow help  
Get-Help Invoke-ManualTrackMapping -Examples

# Installation help
Get-Help Install-TagLibSharp -Full
```

### Common Issues
1. **TagLib-Sharp missing**: Use `Install-TagLibSharp` 
2. **Spotify connection**: Use `Connect-Spotify` (from Spotishell module)
3. **Track order problems**: Use the manual workflow (see guides above)
4. **Performance issues**: Check the Performance Guide

### Support
- 🐛 **Issues**: Report bugs via GitHub Issues
- 💡 **Feature Requests**: Submit via GitHub Discussions  
- 📖 **Documentation**: Check guides above or use built-in help
- 🧪 **Testing**: Run test scripts in `tests/` folder

---

**Documentation last updated**: September 22, 2025