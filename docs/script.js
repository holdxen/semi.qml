/* ==========================================================================
   计划文档的交互：主题切换 + 色板渲染 + 目录高亮
   色板数据由 packages/semi-theme-default/scss/_palette.scss 解析得到，
   未做任何人工调整 —— 页面显示的就是源库里的真实值。
   ========================================================================== */

const PALETTE = {
    hues: [
        "amber", "blue", "cyan", "green", "indigo", "light-blue", "light-green",
        "lime", "orange", "pink", "purple", "red", "teal", "violet", "yellow", "grey",
    ],
    light: {
        amber: ["#fefbeb", "#fcf5ce", "#f9e89e", "#f6d86f", "#f3c641", "#f0b114", "#c88a0f", "#a0660a", "#784606", "#502b03"],
        blue: ["#eaf5ff", "#cbe7fe", "#98cdfd", "#65b2fc", "#3295fb", "#0064fa", "#0062d6", "#004fb3", "#003d8f", "#002c6b"],
        cyan: ["#e5f7f8", "#c2eff0", "#8adde2", "#58cbd3", "#2cb8c5", "#05a4b6", "#038698", "#016979", "#004d5b", "#00323d"],
        green: ["#ecf7ec", "#d0f0d1", "#a4e0a7", "#7dd182", "#5ac262", "#3bb346", "#30953b", "#25772f", "#1b5924", "#113c18"],
        indigo: ["#eceff8", "#d1d8f0", "#a7b3e1", "#8090d3", "#5e6fc4", "#3f51b5", "#3342a1", "#28348c", "#1f2878", "#171d63"],
        "light-blue": ["#e9f7fd", "#c9ecfc", "#95d8f8", "#62c3f5", "#30acf1", "#0095ee", "#007bca", "#0063a7", "#004b83", "#00355f"],
        "light-green": ["#f3f8ec", "#e3f0d0", "#c8e2a5", "#add37e", "#93c55b", "#7bb63c", "#649830", "#4e7926", "#395b1b", "#253d12"],
        lime: ["#f2fae6", "#e3f6c5", "#cbed8e", "#b7e35b", "#a7da2c", "#9bd100", "#7eae00", "#638b00", "#486800", "#2f4600"],
        orange: ["#fff8ea", "#feeecc", "#fed998", "#fdc165", "#fda633", "#fc8800", "#d26700", "#a84a00", "#7e3100", "#541d00"],
        pink: ["#fdecef", "#fbcfd8", "#f6a0b5", "#f27396", "#ed487b", "#e91e63", "#c51356", "#a20b48", "#7e053a", "#5a012b"],
        purple: ["#f7e9f7", "#efcaf0", "#dd9be0", "#c96fd1", "#b449c2", "#9e28b3", "#871e9e", "#71168a", "#5c0f75", "#490a61"],
        red: ["#fef2ed", "#feddd2", "#fdb7a5", "#fb9078", "#fa664c", "#f93920", "#d52515", "#b2140c", "#8e0805", "#6a0103"],
        teal: ["#e4f7f4", "#c0f0e8", "#87e0d3", "#54d1c1", "#27c2b0", "#00b3a1", "#009589", "#00776f", "#005955", "#003c3a"],
        violet: ["#f3edf9", "#e2d1f4", "#c4a7e9", "#a67fdd", "#885bd2", "#6a3ac7", "#572fb3", "#46259e", "#361c8a", "#281475"],
        yellow: ["#fffdea", "#fefbcb", "#fdf398", "#fce865", "#fbda32", "#fac800", "#d0aa00", "#a78b00", "#7d6a00", "#534800"],
        grey: ["#f9f9f9", "#e6e8ea", "#c6cacd", "#a7abb0", "#888d92", "#6b7075", "#555b61", "#41464c", "#2e3238", "#1c1f23"],
    },
    dark: {
        amber: ["#512e09", "#794b0f", "#a16b16", "#ca8f1e", "#f2b726", "#f5ca50", "#f7db7a", "#faeaa6", "#fcf6d2", "#fefbed"],
        blue: ["#053170", "#0a4694", "#135cb8", "#1d75db", "#2990ff", "#54a9ff", "#7fc1ff", "#a9d7ff", "#d4ecff", "#eff8ff"],
        cyan: ["#04343d", "#074f5c", "#0a6c7b", "#0e8999", "#13a8b8", "#38bbc6", "#62cdd4", "#91dfe3", "#c6eff1", "#e7f7f8"],
        green: ["#123c19", "#1c5a25", "#277731", "#32953d", "#3eb349", "#5dc264", "#7fd184", "#a6e1a8", "#d0f0d1", "#ecf7ec"],
        indigo: ["#171e65", "#20297a", "#29368e", "#3444a3", "#4053b7", "#5f71c5", "#8191d4", "#a7b4e2", "#d1d8f1", "#edeff8"],
        "light-blue": ["#003761", "#004d85", "#0366a9", "#0a81cc", "#139ff0", "#40b4f3", "#6ec8f6", "#9ddcf9", "#ceeefc", "#ebf8fe"],
        "light-green": ["#263d13", "#3b5c1d", "#517b28", "#679934", "#7fb840", "#97c65f", "#b0d481", "#c9e3a7", "#e4f1d1", "#f3f8ed"],
        lime: ["#314603", "#4b6905", "#678d09", "#84b00c", "#a2d311", "#aedc3a", "#bde566", "#cfed96", "#e5f6c9", "#f3fbe9"],
        orange: ["#551f03", "#803506", "#aa500a", "#d56f0f", "#ff9214", "#ffae43", "#ffc772", "#ffdda1", "#ffefd0", "#fff9ed"],
        pink: ["#5c0730", "#800e41", "#a41751", "#c72261", "#eb2f71", "#ef5686", "#f37e9f", "#f7a8bc", "#fbd3dc", "#fdeef1"],
        purple: ["#4a1061", "#5e1776", "#731f8a", "#89289f", "#a033b3", "#b553c2", "#ca78d1", "#dda0e1", "#efcef0", "#f7ebf7"],
        red: ["#6c090b", "#901110", "#b42019", "#d73324", "#fb4932", "#fc725a", "#fd9983", "#fdbeac", "#fee0d5", "#fff3ef"],
        teal: ["#023c39", "#045a55", "#07776f", "#0a9588", "#0eb3a1", "#33c2b0", "#5ed1c1", "#8ee1d3", "#c4f0e8", "#e6f7f4"],
        violet: ["#401b77", "#4c248c", "#582ea0", "#6439b5", "#7246c9", "#8865d4", "#a288df", "#beade9", "#ddd4f4", "#f1eefa"],
        yellow: ["#544903", "#7e6c06", "#a88e0a", "#d2af0f", "#fcce14", "#fdde43", "#fdeb71", "#fef5a0", "#fefbd0", "#fffeec"],
        grey: ["#1c1f23", "#2e3238", "#41464c", "#555b61", "#6b7075", "#888d92", "#a7abb0", "#c6cacd", "#e6e8ea", "#f9f9f9"],
    },
};

const root = document.documentElement;
const paletteEl = document.getElementById("palette");
const legendEl = document.getElementById("paletteLegend");
const toggleEl = document.getElementById("themeToggle");
const labelEl = document.getElementById("themeLabel");

function renderPalette(theme) {
    const scale = PALETTE[theme];
    paletteEl.replaceChildren(
        ...PALETTE.hues.map((hue) => {
            const row = document.createElement("div");
            row.className = "palette__row";

            const name = document.createElement("div");
            name.className = "palette__name";
            name.textContent = hue;
            row.appendChild(name);

            scale[hue].forEach((hex, level) => {
                const cell = document.createElement("div");
                cell.className = "palette__swatch";
                cell.style.background = hex;
                cell.dataset.hex = `${hex}\n${level}`;
                cell.title = `--semi-${hue}-${level}: ${hex}`;
                row.appendChild(cell);
            });

            return row;
        })
    );

    if (!legendEl.dataset.ready) {
        const head = document.createElement("span");
        legendEl.appendChild(head);
        for (let i = 0; i < 10; i++) {
            const s = document.createElement("span");
            s.textContent = String(i);
            legendEl.appendChild(s);
        }
        legendEl.dataset.ready = "1";
    }
}

function applyTheme(theme, persist) {
    root.dataset.theme = theme;
    renderPalette(theme);
    labelEl.textContent = theme === "dark" ? "浅色" : "深色";
    toggleEl.setAttribute(
        "aria-label",
        theme === "dark" ? "切换到浅色模式" : "切换到深色模式"
    );
    if (persist) {
        try {
            localStorage.setItem("semi-plan-theme", theme);
        } catch (e) {
            /* 隐私模式下忽略 */
        }
    }
}

function initialTheme() {
    try {
        const saved = localStorage.getItem("semi-plan-theme");
        if (saved === "light" || saved === "dark") return saved;
    } catch (e) {
        /* 忽略 */
    }
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

toggleEl.addEventListener("click", () => {
    applyTheme(root.dataset.theme === "dark" ? "light" : "dark", true);
});

applyTheme(initialTheme(), false);

/* ---- 目录滚动高亮 ---- */

const tocLinks = [...document.querySelectorAll(".toc a")];
const sections = tocLinks
    .map((a) => document.querySelector(a.getAttribute("href")))
    .filter(Boolean);

if (sections.length) {
    const visible = new Map();
    const observer = new IntersectionObserver(
        (entries) => {
            entries.forEach((e) => visible.set(e.target.id, e.isIntersecting));
            const current = sections.find((s) => visible.get(s.id));
            tocLinks.forEach((a) =>
                a.classList.toggle("is-active", current && a.getAttribute("href") === `#${current.id}`)
            );
        },
        { rootMargin: "-72px 0px -70% 0px", threshold: 0 }
    );
    sections.forEach((s) => observer.observe(s));
}
