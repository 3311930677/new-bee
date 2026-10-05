import { Client } from './godot-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import { StdioClientTransport } from './godot-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import { writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const project = path.join(root, '\u8fdc\u5f81');
const out = path.join(project, 'tools', '_logs', 'bag_ui_review');
await mkdir(out, {recursive:true});
const client = new Client({name:'expedition-ui-review',version:'1.0'});
const transport = new StdioClientTransport({command:process.execPath,args:[path.join(root,'tools/godot-mcp/launch.mjs')],env:{...process.env,GODOT_PATH:path.join(root,'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'),GODOT_PROJECT_PATH:project},stderr:'pipe'});
transport.stderr?.on('data', d => process.stderr.write(d));
try {
  await client.connect(transport);
  const name = process.argv[2] ?? 'list';
  if (name === 'list') {
    const list = await client.listTools();
    await writeFile(path.join(out,'mcp_tool_schemas.json'), JSON.stringify(list,null,2));
    console.log(JSON.stringify(list.tools.map(t=>({name:t.name,description:t.description})),null,2));
  } else {
    const args = JSON.parse(process.argv[3] ?? '{}');
    if (!args.project) args.project = project;
    const result = await client.callTool({name,arguments:args},undefined,{timeout:120000});
    await writeFile(path.join(out,name+'.json'),JSON.stringify(result,null,2));
    console.log(JSON.stringify(result));
  }
} finally { await client.close(); }
