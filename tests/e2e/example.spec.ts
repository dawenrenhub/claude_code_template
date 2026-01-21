import { test, expect } from '@playwright/test';

test.describe('示例测试', () => {
  test('首页加载', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/.*/);
  });
});
