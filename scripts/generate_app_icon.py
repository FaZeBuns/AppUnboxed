import os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_ultra_sleek_app_icon():
    W, H = 1024, 1024
    scale = 3  # 3072x3072
    sw, sh = W * scale, H * scale
    
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # 1. Subtle, high-end radial background vignette
    cx, cy = sw // 2, sh // 2
    for r in range(int(640 * scale), 0, -int(12 * scale)):
        ratio = 1.0 - (r / (640 * scale))
        alpha = int(45 * (ratio ** 2.2))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(36, 42, 54, alpha))

    # 2. Isometric geometry
    box_size = int(350 * scale)
    angle_rad = math.radians(30)
    cos30 = math.cos(angle_rad)
    sin30 = math.sin(angle_rad)

    dx = int(box_size * cos30)
    dy = int(box_size * sin30)
    h_box = int(box_size * 0.98)

    # Key vertices:
    center_y = cy - int(25 * scale)
    V_center = (cx, center_y)
    V_top = (cx, center_y - dy * 2)
    V_left = (cx - dx, center_y - dy)
    V_right = (cx + dx, center_y - dy)

    V_bottom_center = (cx, center_y + h_box)
    V_bottom_left = (cx - dx, center_y - dy + h_box)
    V_bottom_right = (cx + dx, center_y - dy + h_box)

    # 3. Ground contact shadow
    shadow_img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow_img)
    sc_y = center_y + h_box + int(35 * scale)
    s_rx = int(dx * 1.3)
    s_ry = int(dy * 1.4)
    sdraw.ellipse([cx - s_rx, sc_y - s_ry, cx + s_rx, sc_y + s_ry], fill=(0, 0, 0, 255))
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(int(45 * scale)))
    img.alpha_composite(shadow_img)
    draw = ImageDraw.Draw(img)

    # 4. Solid 3D Cube Faces
    poly_top = [V_center, V_left, V_top, V_right]
    poly_left = [V_center, V_bottom_center, V_bottom_left, V_left]
    poly_right = [V_center, V_bottom_center, V_bottom_right, V_right]

    # Solid matte metallic fills with rich contrast
    draw.polygon(poly_top, fill=(58, 62, 72, 255))
    draw.polygon(poly_left, fill=(30, 33, 39, 255))
    draw.polygon(poly_right, fill=(16, 17, 21, 255))

    # Helper for insetting polygon
    def inset_poly(pts, inset_px):
        c_x = sum(p[0] for p in pts) / len(pts)
        c_y = sum(p[1] for p in pts) / len(pts)
        res = []
        for p in pts:
            vx = p[0] - c_x
            vy = p[1] - c_y
            dist = math.hypot(vx, vy)
            factor = max(0.1, (dist - inset_px) / dist)
            res.append((int(c_x + vx * factor), int(c_y + vy * factor)))
        return res

    # 5. Inner Inset Panels
    margin = int(24 * scale)
    top_inset = inset_poly(poly_top, margin)
    left_inset = inset_poly(poly_left, margin)
    right_inset = inset_poly(poly_right, margin)

    # Inset fills with crisp white wireframe outline
    draw.polygon(top_inset, fill=(46, 50, 58, 255), outline=(255, 255, 255, 230), width=int(3.5 * scale))
    draw.polygon(left_inset, fill=(22, 24, 28, 255), outline=(255, 255, 255, 200), width=int(3.5 * scale))
    draw.polygon(right_inset, fill=(11, 12, 15, 255), outline=(255, 255, 255, 170), width=int(3.5 * scale))

    # 6. Sleek Outer White Edge Bevels
    rim_w = int(7 * scale)
    draw.line([V_top, V_left], fill=(255, 255, 255, 255), width=rim_w)
    draw.line([V_top, V_right], fill=(255, 255, 255, 255), width=rim_w)
    draw.line([V_center, V_top], fill=(255, 255, 255, 255), width=rim_w)
    draw.line([V_center, V_left], fill=(255, 255, 255, 255), width=rim_w)
    draw.line([V_center, V_right], fill=(255, 255, 255, 255), width=rim_w)
    draw.line([V_center, V_bottom_center], fill=(255, 255, 255, 255), width=int(8 * scale))
    draw.line([V_left, V_bottom_left], fill=(235, 240, 250, 240), width=rim_w)
    draw.line([V_right, V_bottom_right], fill=(195, 200, 210, 220), width=rim_w)
    draw.line([V_bottom_left, V_bottom_center], fill=(215, 220, 230, 220), width=rim_w)
    draw.line([V_bottom_center, V_bottom_right], fill=(175, 180, 190, 200), width=rim_w)

    # 7. Reinforced Corner Caps
    cap_r = int(10 * scale)
    for pt in [V_center, V_top, V_left, V_right, V_bottom_center, V_bottom_left, V_bottom_right]:
        draw.ellipse([pt[0] - cap_r, pt[1] - cap_r, pt[0] + cap_r, pt[1] + cap_r],
                     fill=(255, 255, 255, 255), outline=(0, 0, 0, 220), width=int(2.5 * scale))
        inner_r = int(3.5 * scale)
        draw.ellipse([pt[0] - inner_r, pt[1] - inner_r, pt[0] + inner_r, pt[1] + inner_r],
                     fill=(70, 75, 85, 255))

    # 8. Render Question Marks
    font_path = None
    for candidate in [
        "C:/Windows/Fonts/segoeuib.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    ]:
        if os.path.exists(candidate):
            font_path = candidate
            break

    if font_path:
        q_font = ImageFont.truetype(font_path, int(220 * scale))
    else:
        q_font = ImageFont.load_default()

    def make_q_mark(w, h, color, glow_color):
        temp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        tdraw = ImageDraw.Draw(temp)
        text = "?"
        bbox = tdraw.textbbox((0, 0), text, font=q_font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (w - tw) // 2 - bbox[0]
        ty = (h - th) // 2 - bbox[1]

        # White glow
        glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        gdraw = ImageDraw.Draw(glow)
        gdraw.text((tx, ty), text, font=q_font, fill=glow_color)
        glow = glow.filter(ImageFilter.GaussianBlur(int(10 * scale)))
        temp.alpha_composite(glow)

        tdraw.text((tx, ty), text, font=q_font, fill=color)
        return temp

    def face_center(pts):
        return (int(sum(p[0] for p in pts) / len(pts)), int(sum(p[1] for p in pts) / len(pts)))

    left_center = face_center(left_inset)
    right_center = face_center(right_inset)
    top_center = face_center(top_inset)

    pw, ph = int(280 * scale), int(340 * scale)

    # --- LEFT FACE QUESTION MARK ---
    q_left_raw = make_q_mark(pw, ph, (255, 255, 255, 255), (255, 255, 255, 180))
    m_left = (1.0, 0.0, 0, -sin30/cos30, 1.0, int(pw * sin30/cos30 * 0.5))
    q_left_skew = q_left_raw.transform((pw, int(ph * 1.3)), Image.AFFINE, m_left, resample=Image.BICUBIC)
    q_left_skew = q_left_skew.resize((int(pw * cos30 * 0.95), int(ph * 0.95)), Image.LANCZOS)
    img.alpha_composite(q_left_skew, (left_center[0] - q_left_skew.width // 2, left_center[1] - q_left_skew.height // 2))

    # --- RIGHT FACE QUESTION MARK ---
    q_right_raw = make_q_mark(pw, ph, (235, 240, 250, 245), (210, 220, 240, 140))
    m_right = (1.0, 0.0, 0, sin30/cos30, 1.0, -int(pw * sin30/cos30 * 0.5))
    q_right_skew = q_right_raw.transform((pw, int(ph * 1.3)), Image.AFFINE, m_right, resample=Image.BICUBIC)
    q_right_skew = q_right_skew.resize((int(pw * cos30 * 0.95), int(ph * 0.95)), Image.LANCZOS)
    img.alpha_composite(q_right_skew, (right_center[0] - q_right_skew.width // 2, right_center[1] - q_right_skew.height // 2))

    # --- TOP FACE QUESTION MARK (Centered accurately) ---
    q_top_raw = make_q_mark(pw, int(ph * 0.8), (255, 255, 255, 255), (255, 255, 255, 200))
    q_top_rot = q_top_raw.rotate(-35, resample=Image.BICUBIC, expand=True)
    q_top_skew = q_top_rot.resize((int(dx * 0.9), int(dy * 1.05)), Image.LANCZOS)
    img.alpha_composite(q_top_skew, (top_center[0] - q_top_skew.width // 2, top_center[1] - q_top_skew.height // 2 + int(6 * scale)))

    # 9. Downsample back to 1024x1024 master
    final_1024 = img.resize((W, H), Image.LANCZOS)

    # Convert to standard 24-bit RGB (no alpha)
    rgb_1024 = Image.new("RGB", (W, H), (0, 0, 0))
    rgb_1024.paste(final_1024, mask=final_1024.split()[3])

    # Save to Resources
    rgb_1024.save("Resources/AppIcon1024.png", format="PNG")
    rgb_1024.resize((180, 180), Image.LANCZOS).save("Resources/AppIcon60x60@3x.png", format="PNG")
    rgb_1024.resize((120, 120), Image.LANCZOS).save("Resources/AppIcon60x60@2x.png", format="PNG")
    rgb_1024.resize((152, 152), Image.LANCZOS).save("Resources/AppIcon76x76@2x~ipad.png", format="PNG")
    rgb_1024.resize((167, 167), Image.LANCZOS).save("Resources/AppIcon83.5x83.5@2x~ipad.png", format="PNG")

    print("Generated ultra sleek 3D black and white app icons in Resources/!")

if __name__ == "__main__":
    create_ultra_sleek_app_icon()
