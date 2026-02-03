import { expect } from 'vitest';
import * as matchers from '@testing-library/jest-dom/matchers';
import '@testing-library/jest-dom/vitest';

expect.extend(matchers);

// Mock Web Animations API for happy-dom
if (typeof Element !== 'undefined' && !Element.prototype.animate) {
	Element.prototype.animate = function () {
		return {
			cancel: () => {},
			finish: () => {},
			pause: () => {},
			play: () => {},
			reverse: () => {},
			onfinish: null,
			oncancel: null
		} as Animation;
	};
}
