# AI 自主 E2E 测试工作流配置 (Ralph + Playwright)

本文档描述了如何配置 Playwright 以适应 Claude/Ralph 的 CLI 自主循环，使其能够“编写代码 -> 运行测试 -> 读取报错 -> 自动修复”。

## 1. 核心原理
由于 Claude 在 CLI 模式下无法看到浏览器界面，我们需要：
1. **强制 Headless 模式**：防止浏览器弹窗阻塞进程。
2. **极简文本反馈**：创建一个自定义 Reporter，只输出错误信息，过滤掉无关的进度条和系统日志，节省 Token 并提高 Claude 的阅读准确率。

---

## 2. 项目配置 (Human Setup)

请在项目中创建以下文件和配置。

### A. 创建 LLM 专用 Reporter
新建文件: `playwright/llm-reporter.ts`
*(这是一个零依赖的 Reporter，专门为 AI 优化输出格式)*

```typescript
import { Reporter, TestCase, TestResult } from '@playwright/test/reporter';

class LLMReporter implements Reporter {
  // 测试开始时不输出，节省 Token
  onTestBegin(test: TestCase) {}

  // 只有测试结束时才处理
  onTestEnd(test: TestCase, result: TestResult) {
    // 我们只关心失败的测试
    if (result.status === 'failed') {
      console.log(`\n❌ TEST FAILED: ${test.title}`);
      console.log(`File: ${test.location.file}`);
      
      // 提取核心报错信息
      if (result.error) {
        // 去除 ANSI 颜色代码，方便 AI 读取
        const cleanMessage = result.error.message?.replace(/\u001b\[.*?m/g, '') || '';
        console.log(`Error Message: ${cleanMessage}`);
        
        // 如果有具体的值对比（Expected vs Received），打印出来
        if (result.error.value) console.log(`Value Details: ${result.error.value}`);
        
        // 打印源码位置
        console.log(`Line: ${test.location.line}, Column: ${test.location.column}`);
      }
      console.log('---------------------------------------------------');
    }
  }

  // 总结
  onEnd(result: any) {
    if (result.status === 'passed') {
      console.log(`\n✅ ALL TESTS PASSED (${result.passed} tests).`);
    } else {
      console.log(`\n⚠️  SUMMARY: ${result.failed} tests failed.`);
    }
  }
}

export default LLMReporter;