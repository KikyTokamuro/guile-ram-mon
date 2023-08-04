setInterval(() => {
	getMemoryStats().then((stats) => {
		const memory = new LinerBar("#memory", {
			title: `Memory (${stats["ram-total"]} Mb)`,
			items: [
				{ name: `Free (${stats["ram-free"]} Mb)`, value: stats["ram-free"], color: "#badc58" },
				{ name: `Used (${stats["ram-used"]} Mb)`, value: stats["ram-used"], color: "#ff7979" }
			]
		});
		memory.render();

		const swap = new LinerBar("#swap", {
			title: `Swap (${stats["swap-total"]} Mb)`,
			items: [
				{ name: `Free (${stats["swap-free"]} Mb)`, value: stats["swap-free"], color: "#badc58" },
				{ name: `Used (${stats["swap-used"]} Mb)`, value: stats["swap-used"], color: "#ff7979" }
			]
		});
		swap.render();
	});
}, 5000);
