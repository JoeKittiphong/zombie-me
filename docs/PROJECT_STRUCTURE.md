# โครงสร้างโปรเจกต์ I Made Zombies

ใช้โครงสร้างตามฟีเจอร์: ฉาก `.tscn` และสคริปต์ `.gd` ที่ทำงานร่วมกันอยู่โฟลเดอร์เดียวกัน ตั้งชื่อไฟล์แบบ `snake_case` และใช้ `res://` สำหรับทรัพยากรในเกม

```text
project.godot
game/
  app/                # จุดเริ่มเกม การเชื่อมหน้าจอ และ scene flow
    main.tscn
    main.gd
    main.gd.uid
  ui/
    screens/          # แต่ละหน้าเป็นโฟลเดอร์ เช่น loading/, main_menu/, lab/, records/
    components/       # ปุ่ม การ์ด และ dialog ที่หลายหน้าใช้ร่วมกัน
  world/
    lab/              # ฉากแล็บ 3D แสง กล้อง และ props ประกอบฉาก
  characters/         # ฉากตัวละคร rig และ animation controller
  gameplay/           # serum, infection, hunting, senses, day_night เมื่อเริ่มทำระบบ
  autoload/           # เฉพาะ state/service ที่จำเป็นต้องใช้ข้ามฉาก
resources/            # .tres และ Resource scripts สำหรับข้อมูลสาร สูตร ด่าน และชนิด NPC
assets/
  models/             # GLB ที่นำเข้าเกม รวม mesh/rig/animation
  textures/           # atlas, diffuse และ UI artwork
  audio/              # music, ambience, sfx, announcements
  fonts/
  icons/
docs/                 # ข้อกำหนดและเอกสารออกแบบ ไม่ถูก Godot import
tests/                # การทดสอบเมื่อมีระบบที่ต้องตรวจ ไม่ถูก Godot import
tools/                # เครื่องมือสร้าง/แปลง asset ไม่ถูก Godot import
```

## หลักการเพิ่มไฟล์

- ฟีเจอร์ใหม่เก็บฉาก สคริปต์ และ resource เฉพาะฟีเจอร์ไว้ใกล้กัน เช่น `game/ui/screens/loading/loading_screen.tscn` และ `loading_screen.gd`
- Asset ที่ใช้หลายฟีเจอร์อยู่ `assets/`; ข้อมูลที่นำกลับมาใช้ได้และปรับใน Inspector อยู่ `resources/`
- เก็บไฟล์ `.gd.uid` คู่กับสคริปต์เสมอ รวมถึงตอนย้ายหรือ rename เพื่อรักษาการอ้างอิง
- `.godot/` เป็น cache ที่ Godot สร้าง ไม่ commit; ไฟล์ `.import` ข้าง asset เป็น metadata ที่ Godot จัดการ อย่าแก้เอง
- เก็บไฟล์ Blender ต้นฉบับขนาดใหญ่ในงาน art แยกจากโฟลเดอร์ runtime แล้ว export GLB มา `assets/models/` ใช้ Git LFS เมื่อจำเป็น
- ใช้ signal เชื่อม UI กับระบบเกม แยกข้อมูลจากหน้าตา และอย่าให้ autoload เป็นที่รวมทุกระบบ
- โฟลเดอร์ว่างมี `.gitkeep` ให้ติด version control; ลบออกได้เมื่อมีไฟล์จริง

## สถานะต้นแบบ

`game/app/main.gd` ยังสร้างแล็บ หน้าโหลด และเมนูด้วยโค้ดทั้งหมด การย้ายครั้งนี้จัดโครงสร้างไฟล์และรักษาพฤติกรรมเดิม ไม่ได้อ้างว่าแยกระบบเสร็จแล้ว

เมื่อปรับหน้าตารอบต่อไป ให้แยกเป็น:

1. `game/world/lab/lab_environment.tscn` — ฉากแล็บและซอมบี้ตัวอย่าง
2. `game/ui/screens/loading/loading_screen.tscn` — หน้าโหลดและการเปลี่ยนหน้า
3. `game/ui/screens/main_menu/main_menu.tscn` — เมนูหลัก
4. `game/app/main.tscn` — ประกอบฉากและควบคุม flow

โหมด `--smoke-test` ใน main.gd ยังเป็นการตรวจต้นแบบชั่วคราว ต้องย้ายไป tests เมื่อเริ่มมีระบบเกมจริง
