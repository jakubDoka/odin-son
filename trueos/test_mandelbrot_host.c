#include <assert.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint8_t code[24576];
static size_t code_len, received;
static unsigned rendered, published, begun;
static unsigned keyboard_polls, pointer_polls;
static uint64_t first_code_hash, first_pixel_hash;
typedef struct {
    uint32_t route[4];
    uint8_t metadata[4], keys[6], ascii[6];
    uint32_t down[8];
} Keyboard;
typedef struct {
    uint32_t route[6];
    int32_t local_x, local_y, dx, dy, wheel;
    uint32_t buttons, pressed, released, combo, vcursor;
} Pointer;
_Static_assert(sizeof(Keyboard)==64 && offsetof(Keyboard,down)==32,"keyboard ABI");
_Static_assert(sizeof(Pointer)==64 && offsetof(Pointer,local_x)==24,"pointer ABI");
static uint32_t bits(float x) { uint32_t u; memcpy(&u,&x,4); return u; }
static float value(uint32_t u) { float x; memcpy(&x,&u,4); return x; }
static uint64_t hash(const void *p, size_t n) {
    uint64_t h = UINT64_C(14695981039346656037);
    const uint8_t *b = p;
    for (size_t i=0;i<n;i++) h = (h ^ b[i]) * UINT64_C(1099511628211);
    return h;
}
static float execute(float a, float b) {
    uint32_t r[128]={0}; r[1]=bits(a); r[2]=bits(b);
    for (size_t at=0;at<code_len;at+=16) {
        uint32_t w[4]; memcpy(w,code+at,16);
        unsigned op=w[0]&127, dst=w[1]>>24, s0=(w[2]>>8)&255, s1=(w[3]>>8)&255;
        assert(dst>=4 && dst<112 && s0<128);
        uint32_t x=r[s0], y=0;
        if(op!=0x61) {
            assert((w[1]&0x8000) || s1<128);
            y=(w[1]&0x8000)?w[3]:r[s1];
        }
        unsigned type=(w[1]>>4)&15;
        switch(op) {
        case 0x61: r[dst]=(w[1]&0x4000)?w[3]:x; break;
        case 0x40: r[dst]=type==10?bits(value(x)+value(y)):x+y; break;
        case 0x41: r[dst]=type==10?bits(value(x)*value(y)):x*y; break;
        case 0x65: r[dst]=x&y; break;
        case 0x66: r[dst]=x|y; break;
        case 0x67: r[dst]=x^y; break;
        case 0x68: r[dst]=x>>(y&31); break;
        case 0x69: r[dst]=x<<(y&31); break;
        case 0x70: {
            assert(type==10);
            float u=value(x), v=value(y); int yes=0;
            switch(w[2]>>28) {
            case 1: yes=u==v; break; case 2: yes=u!=v; break;
            case 3: yes=u>v; break; case 4: yes=u>=v; break;
            case 5: yes=u<v; break; case 6: yes=u<=v; break;
            default: assert(0);
            }
            r[dst]=yes?UINT32_MAX:0; break;
        }
        default: assert(!"non-ALU instruction in source body");
        }
    }
    return value(r[4]);
}
static float reference(float cx, float cy, unsigned iterations) {
    float zx=0,zy=0,depth=0;
    for(unsigned i=0;i<iterations;i++) {
        float nx=zx*zx-zy*zy+cx, ny=2.0f*zx*zy+cy;
        zx=nx; zy=ny; depth+=1;
        if(zx*zx+zy*zy>4.0f) break;
    }
    return depth*0.04f;
}
uint32_t trueos_cabi_ui4_scene_frame_open_visual(int32_t x, int32_t y, uint32_t w, uint32_t h, uint32_t hz) {
    assert(x==40 && y==40 && w==320 && h==240 && hz==30); return 73;
}
int32_t trueos_cabi_ui4_scene_native_compute_upload_v1(uint32_t w, uint32_t offset, uint32_t total, const void *p, size_t n) {
    assert(w==73 && total>0 && total<=sizeof(code) && total%16==0 && n>0 && n<=2048);
    if(!offset) { received=0; code_len=total; }
    assert(offset==received && code_len==total && n<=total-offset);
    memcpy(code+offset,p,n); received+=n; return 0;
}
int32_t trueos_cabi_ui4_scene_visual_frame_begin(uint32_t w) {
    assert(w==73 && received==code_len && begun==published); begun++; return 0;
}
int32_t trueos_cabi_ui4_scene_native_compute_render_v1(uint32_t w, float ox, float oy, float dx, float dy) {
    assert(w==73 && begun==rendered+1 && rendered<2 && dx>0 && dy>0);
    const char *retained=getenv("TRUEOS_TEST_MANDELBROT_RETAINED");
    if(retained && rendered) {
        float initial_step=3.0f/320.0f, next_step=initial_step*0.8f;
        float expected_x=-2.0f+160.0f*(initial_step-next_step)-4.0f*next_step;
        float expected_y=-1.125f+120.0f*(initial_step-next_step)+2.0f*next_step;
        assert(bits(dx)==bits(next_step) && bits(dy)==bits(next_step));
        assert(bits(ox)==bits(expected_x) && bits(oy)==bits(expected_y));
    }
    uint32_t pixels[64*48];
    for(unsigned y=0;y<48;y++) for(unsigned x=0;x<64;x++) {
        float cx=ox+(float)(x*5)*dx, cy=oy+(float)(y*5)*dy;
        float actual=execute(cx,cy), expected=reference(cx,cy,rendered && !retained?16:25);
        if(bits(actual)!=bits(expected)) {
            fprintf(stderr,"Mandelbrot mismatch (%u,%u): %08x != %08x\n",x,y,bits(actual),bits(expected));
            abort();
        }
        pixels[y*64+x]=bits(actual);
    }
    uint64_t c=hash(code,code_len), p=hash(pixels,sizeof(pixels));
    if(!rendered) { first_code_hash=c; first_pixel_hash=p; }
    else { assert((retained?c==first_code_hash:c!=first_code_hash) && p!=first_pixel_hash); }
    rendered++; return 0;
}
int32_t trueos_cabi_ui4_scene_compute_frame_publish(uint32_t w, uint32_t x, uint32_t y, uint32_t width, uint32_t height) {
    assert(w==73 && !x && !y && width==320 && height==240 && rendered==published+1);
    published++; return 0;
}
int32_t trueos_cabi_ui4_solara_frame_close(uint32_t w) {
    assert(w==73 && begun==rendered && rendered==published);
    const char *retained=getenv("TRUEOS_TEST_MANDELBROT_RETAINED");
    if(retained) {
        if(!strcmp(retained,"keys")) {
            assert(rendered==2 && keyboard_polls==3 && pointer_polls==3);
            puts("PASS retained UI4 no-focus idle, keyboard ABI, pointer zoom/pan, redraw and Q exit");
        } else {
            assert(rendered==1 && keyboard_polls==1);
            assert(pointer_polls==(!strcmp(retained,"pointer-error")?1u:0u));
            puts("PASS retained UI4 input error/closed-window cleanup");
        }
        return 0;
    }
    assert(rendered==2);
    puts("PASS runtime-compiled 25/16 iteration source, native ALU math, ordered UI4 upload/render/publish; hardware mocked");
    return 0;
}
int32_t trueos_cabi_ui4_scene_keyboard_state(uint32_t w, void *out) {
    assert(w==73 && rendered==published && out);
    const char *retained=getenv("TRUEOS_TEST_MANDELBROT_RETAINED"); assert(retained);
    ++keyboard_polls;
    if(!strcmp(retained,"keyboard-error")) return -6;
    if(!strcmp(retained,"closed")) return -3;
    if(keyboard_polls==1) {memset(out,255,sizeof(Keyboard)); return 1;}
    Keyboard *state=out; memset(state,0,sizeof(*state));
    if(keyboard_polls==3) state->down[0]=UINT32_C(1)<<20;
    assert(keyboard_polls<=3);
    return 0;
}
int32_t trueos_cabi_ui4_scene_pointer_event_take(uint32_t w, void *out) {
    assert(w==73 && out);
    const char *retained=getenv("TRUEOS_TEST_MANDELBROT_RETAINED"); assert(retained);
    ++pointer_polls;
    if(!strcmp(retained,"pointer-error")) return -6;
    if(pointer_polls!=2) return 1;
    Pointer *event=out; memset(event,0,sizeof(*event));
    event->local_x=160; event->local_y=120; event->dx=4; event->dy=-2;
    event->wheel=1; event->buttons=1;
    return 0;
}
