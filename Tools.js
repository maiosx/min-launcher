// Curated Design Engineer Tools — mirrors the classic designengineer.tools layout
// Each entry: { name, url, icon? }

.pragma library

var categories = [
  {
    title: "Inspiration",
    columns: 2,
    tools: [
      { name: "60fps", url: "https://60fps.design/" },
      { name: "Awwwards", url: "https://www.awwwards.com/" },
      { name: "Cosmos", url: "https://www.cosmos.so/" },
      { name: "Curated Design", url: "https://www.curated.design/" },
      { name: "Design Spells", url: "https://www.designspells.com/" },
      { name: "Game UI Database", url: "https://www.gameuidatabase.com/" },
      { name: "Godly", url: "https://godly.website/" },
      { name: "HUDS+GUIS", url: "https://hudsandguis.com/" },
      { name: "Interface In Game", url: "https://interfaceingame.com/" },
      { name: "Layers", url: "https://layers.to/" },
      { name: "loadmo.re", url: "https://loadmo.re/" },
      { name: "Minimal Gallery", url: "https://minimal.gallery/" },
      { name: "Minimum", url: "https://www.minimum.design/" },
      { name: "Mobbin", url: "https://mobbin.com/" },
      { name: "Pinterest", url: "https://www.pinterest.com/" },
      { name: "Rebrand", url: "https://rebrand.gallery/" },
      { name: "Saaspo", url: "https://saaspo.com/" },
      { name: "Same Energy", url: "https://same.energy/" },
      { name: "SearchSystem", url: "https://www.searchsystem.co/" },
      { name: "SEESAW", url: "https://www.seesaw.website/" },
      { name: "SOOT SPIRAL", url: "https://spiral.soot.com/" },
      { name: "Supahero", url: "https://www.supahero.io/" }
    ]
  },
  {
    title: "AI Code",
    columns: 1,
    tools: [
      { name: "Bolt.new", url: "https://bolt.new/" },
      { name: "Claude Code", url: "https://claude.ai/code" },
      { name: "Cline", url: "https://github.com/cline/cline" },
      { name: "Cursor", url: "https://cursor.com/" },
      { name: "Google Antigravity", url: "https://antigravity.google/" },
      { name: "OpenAI Codex", url: "https://openai.com/codex/" },
      { name: "Skills", url: "https://skills.sh/" },
      { name: "v0 by Vercel", url: "https://v0.dev/" },
      { name: "Windsurf", url: "https://codeium.com/windsurf" },
      { name: "Zed", url: "https://zed.dev/" }
    ]
  },
  {
    title: "Components",
    columns: 1,
    tools: [
      { name: "21st.dev", url: "https://21st.dev/" },
      { name: "Component Gallery", url: "https://component.gallery/" },
      { name: "Cursify", url: "https://cursify.vercel.app/" },
      { name: "Fancy Components", url: "https://www.fancycomponents.com/" },
      { name: "Framer University Resources", url: "https://www.framer.com/university/" },
      { name: "Motion Primitives", url: "https://motion-primitives.com/" },
      { name: "NumberFlow", url: "https://number-flow.barvian.me/" },
      { name: "React Bits", url: "https://www.reactbits.dev/" },
      { name: "shadcn/ui", url: "https://ui.shadcn.com/" }
    ]
  },
  {
    title: "Web Utility",
    columns: 1,
    tools: [
      { name: "Color.review", url: "https://color.review/" },
      { name: "Easing Editor", url: "https://easings.net/" },
      { name: "Easing Functions", url: "https://easings.net/" },
      { name: "Easing Gradients", url: "https://larsenwork.com/easing-gradients/" }
    ]
  },
  {
    title: "Desktop Utility",
    columns: 1,
    tools: [
      { name: "Claude Cowork", url: "https://claude.ai/" },
      { name: "Granola", url: "https://www.granola.so/" },
      { name: "LocalSend", url: "https://localsend.org/" },
      { name: "Raycast", url: "https://www.raycast.com/" }
    ]
  },
  {
    title: "Video & Capture",
    columns: 1,
    tools: [
      { name: "LosslessCut", url: "https://github.com/mifi/lossless-cut" },
      { name: "NVIDIA ShadowPlay", url: "https://www.nvidia.com/en-us/geforce/geforce-experience/shadowplay/" },
      { name: "OBS Studio", url: "https://obsproject.com/" },
      { name: "Parsec", url: "https://parsec.app/" }
    ]
  },
  {
    title: "Whiteboard",
    columns: 1,
    tools: [
      { name: "Excalidraw", url: "https://excalidraw.com/" },
      { name: "FigJam", url: "https://www.figma.com/figjam/" },
      { name: "Miro", url: "https://miro.com/" },
      { name: "Muse", url: "https://museapp.com/" }
    ]
  }
]

function flatTools() {
  var list = []
  for (var i = 0; i < categories.length; i++) {
    var cat = categories[i]
    for (var j = 0; j < cat.tools.length; j++) {
      list.push({
        name: cat.tools[j].name,
        url: cat.tools[j].url,
        category: cat.title
      })
    }
  }
  return list
}
