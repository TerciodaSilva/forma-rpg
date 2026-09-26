(function () {
	'use strict';

	// Replace this with the Publisher ID from AdSense, for example:
	// ca-pub-1234567890123456
	const PUBLISHER_ID = 'ca-pub-1083671059005419';
	const AD_FREQUENCY_HINT = '120s';

	let sequence = 0;
	const placements = Object.create(null);

	function validPublisherId(value) {
		return /^ca-pub-\d{16}$/.test(value);
	}

	function markDone(name) {
		if (placements[name]) {
			placements[name].done = true;
		}
	}

	function initialize() {
		if (!validPublisherId(PUBLISHER_ID)) {
			window.FORMA_ADS = {
				request: function (name) {
					placements[name] = { done: true };
				},
				isDone: function (name) {
					return !placements[name] || placements[name].done;
				},
			};
			console.info('[FORMA] Ads aguardando o Publisher ID do AdSense.');
			return;
		}

		window.adsbygoogle = window.adsbygoogle || [];
		window.adBreak = window.adConfig = function (options) {
			window.adsbygoogle.push(options);
		};

		const script = document.createElement('script');
		script.async = true;
		script.crossOrigin = 'anonymous';
		script.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=' + encodeURIComponent(PUBLISHER_ID);
		script.dataset.adClient = PUBLISHER_ID;
		script.dataset.adFrequencyHint = AD_FREQUENCY_HINT;
		document.head.appendChild(script);

		window.adConfig({
			preloadAdBreaks: 'auto',
			sound: 'on',
		});

		window.FORMA_ADS = {
			request: function (name) {
				const token = ++sequence;
				placements[name] = { done: false, token: token };
				window.adBreak({
					type: 'start',
					name: 'forma_' + name,
					adBreakDone: function () {
						if (placements[name] && placements[name].token === token) {
							markDone(name);
						}
					},
				});
			},
			isDone: function (name) {
				return !placements[name] || placements[name].done;
			},
		};
	}

	initialize();
}());
