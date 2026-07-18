#!/usr/bin/env python3
"""Record repeatable local Web layout/load evidence for the HD art contract.

Run after `tools/build_web.sh` while the bundle is served with `tools/serve_web.py`:
  python3 tools/measure_web_playtest.py --url http://127.0.0.1:8765/index.html

This is a local Chromium-emulation tool, not a substitute for real-device
network or frame-time validation. It records desktop and Android-landscape
layout, bundle resource transfers, console errors, and headless frame samples.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import time
from pathlib import Path
from typing import Any

try:
    from playwright.async_api import Browser, Page, async_playwright
except ImportError as error:
    raise SystemExit(
        "Playwright is required. Install it in the active Python environment "
        "and run `playwright install chromium`."
    ) from error

CASES: tuple[dict[str, Any], ...] = (
    {
        "name": "desktop_1280x720_dpr1",
        "viewport": {"width": 1280, "height": 720},
        "device_scale_factor": 1,
        "is_mobile": False,
        "has_touch": False,
    },
    {
        "name": "android_landscape_915x412_dpr2_5_emulated",
        "viewport": {"width": 915, "height": 412},
        "device_scale_factor": 2.5,
        "is_mobile": True,
        "has_touch": True,
        "user_agent": (
            "Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36"
        ),
    },
)


async def _frame_metrics(page: Page, sample_count: int) -> dict[str, float | int]:
    return await page.evaluate(
        """async (framesToSample) => {
            const deltas = [];
            let previous = performance.now();
            await new Promise(resolve => {
                const tick = now => {
                    deltas.push(now - previous);
                    previous = now;
                    if (deltas.length >= framesToSample) resolve();
                    else requestAnimationFrame(tick);
                };
                requestAnimationFrame(tick);
            });
            const sorted = [...deltas].sort((left, right) => left - right);
            const percentile = fraction => sorted[
                Math.min(sorted.length - 1, Math.floor(sorted.length * fraction))
            ];
            return {
                count: deltas.length,
                median_ms: percentile(0.5),
                p95_ms: percentile(0.95),
                max_ms: sorted.at(-1),
            };
        }""",
        sample_count,
    )


async def _measure_case(
    browser: Browser,
    url: str,
    output_directory: Path,
    config: dict[str, Any],
    sample_count: int,
) -> dict[str, Any]:
    context = await browser.new_context(
        viewport=config["viewport"],
        device_scale_factor=config["device_scale_factor"],
        is_mobile=config["is_mobile"],
        has_touch=config["has_touch"],
        user_agent=config.get("user_agent"),
    )
    page = await context.new_page()
    errors: list[str] = []
    page.on(
        "console",
        lambda message: errors.append(f"console:{message.type}:{message.text}")
        if message.type == "error"
        else None,
    )
    page.on("pageerror", lambda error: errors.append(f"pageerror:{error}"))

    started = time.monotonic()
    response = await page.goto(url, wait_until="load", timeout=60_000)
    wall_load_ms = round((time.monotonic() - started) * 1000.0, 1)
    await page.wait_for_timeout(4_000)
    timing = await page.evaluate(
        """() => {
            const navigation = performance.getEntriesByType('navigation')[0];
            const resources = performance.getEntriesByType('resource').map(resource => ({
                name: resource.name.split('/').pop(),
                duration_ms: resource.duration,
                transfer_size_bytes: resource.transferSize,
            }));
            const canvas = document.querySelector('canvas');
            const canvasRect = canvas ? canvas.getBoundingClientRect() : null;
            const viewport = {
                inner_width: innerWidth,
                inner_height: innerHeight,
                device_pixel_ratio: devicePixelRatio,
                touch_points: navigator.maxTouchPoints,
            };
            const canvasMetrics = canvas && canvasRect ? {
                css_left: canvasRect.left,
                css_top: canvasRect.top,
                css_width: canvasRect.width,
                css_height: canvasRect.height,
                backing_width: canvas.width,
                backing_height: canvas.height,
                css_aspect_ratio: canvasRect.width / canvasRect.height,
                backing_scale_x: canvas.width / canvasRect.width,
                backing_scale_y: canvas.height / canvasRect.height,
                backing_matches_dpr: Math.abs(canvas.width / canvasRect.width - devicePixelRatio) < 0.05
                    && Math.abs(canvas.height / canvasRect.height - devicePixelRatio) < 0.05,
                inside_viewport: canvasRect.left >= 0 && canvasRect.top >= 0
                    && canvasRect.right <= innerWidth && canvasRect.bottom <= innerHeight,
                left_margin: canvasRect.left,
                right_margin: innerWidth - canvasRect.right,
                top_margin: canvasRect.top,
                bottom_margin: innerHeight - canvasRect.bottom,
            } : null;
            return {
                viewport,
                canvas: canvasMetrics,
                navigation: navigation ? {
                    dom_content_loaded_ms: navigation.domContentLoadedEventEnd,
                    load_ms: navigation.loadEventEnd,
                } : null,
                resources,
            };
        }"""
    )
    screenshot_path = output_directory / f"{config['name']}.png"
    await page.screenshot(path=str(screenshot_path))
    result = {
        "case": config["name"],
        "http_status": response.status if response is not None else None,
        "wall_load_ms": wall_load_ms,
        "timing": timing,
        "headless_frame_metrics": await _frame_metrics(page, sample_count),
        "console_errors": errors,
        "screenshot": str(screenshot_path),
    }
    await context.close()
    return result


async def _run(arguments: argparse.Namespace) -> list[dict[str, Any]]:
    arguments.output_directory.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(headless=True)
        results = [
            await _measure_case(
                browser,
                arguments.url,
                arguments.output_directory,
                config,
                arguments.frame_samples,
            )
            for config in CASES
        ]
        await browser.close()
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True, help="HTTP(S) URL for index.html")
    parser.add_argument(
        "--output-directory",
        type=Path,
        default=Path(".playtest-build/measurements"),
        help="Ignored directory for JSON evidence and screenshots.",
    )
    parser.add_argument("--frame-samples", type=int, default=180)
    arguments = parser.parse_args()
    if arguments.frame_samples < 1:
        parser.error("--frame-samples must be positive")
    results = asyncio.run(_run(arguments))
    result_path = arguments.output_directory / "web_measurements.json"
    result_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(result_path)


if __name__ == "__main__":
    main()
