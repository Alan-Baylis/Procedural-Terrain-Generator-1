// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/MegaOutputShader"
{
	Properties
	{
      [NoScaleOffset]_LocalPositions ("Local Positions", 2D) = "white" {}
      [NoScaleOffset]_WorldPositions ("World Positions", 2D) = "white" {}
      [NoScaleOffset]_LocalNormals ("Local Normals", 2D) = "white" {}
      [NoScaleOffset]_WorldNormals ("World Normals", 2D) = "white" {}
      [NoScaleOffset]_UVCavity("Cavity map", 2D) = "white" {}
      [NoScaleOffset]_CurveArray("Curve Array", 2DArray) = "black" {}
      _HeightBounds("Height Bounds", Vector) = (0,1,0,0)
      _Pass("Pass", Float) = 0
	
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.5
			#include "UnityCG.cginc"
      
         sampler2D_float _LocalPositions;
         sampler2D_float _WorldPositions;
         sampler2D_float _LocalNormals;
         sampler2D_float _WorldNormals;
         sampler2D_float _UVCavity;
         float _Pass;
         float2 _HeightBounds;
         UNITY_DECLARE_TEX2DARRAY(_CurveArray);


			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

         int Selector2(int t0, int t1, float r, float center)
         {
            return (r < center) ? t0 : t1;
         }

         int Selector3(int t0, int t1, int t2, float r, float sideMin, float sideMax)
         {
            if (r < sideMin)
               return t0;
            else if (r < sideMax)
               return t1;
            return t2;
         }

         int Selector4(int t0, int t1, int t2, int t3, float r, float sMin, float sMid, float sMax)
         {
            if (r < sMin)
               return t0;
            else if (r < sMid)
               return t1;
            else if (r < sMax)
               return t2;
            return t3;
         }

         int SelectorN(float r, float4 index, float4 index2, float count)
         {
            r = saturate(r);
            float stp = 1.0 / count;
            if (r <= stp)
               return (int)index.x;
            else if (r <= stp*2)
               return (int)index.y;
            else if (r <= stp*3)
               return (int)index.z;
            else if (r <= stp*4)
               return (int)index.w;
            else if (r <= stp*5)
               return (int)index2.x;
            else if (r <= stp*6)
               return (int)index2.y;
            else if (r <= stp*7)
               return (int)index2.z;

            return (int)index2.w;

         }


         //
         //  Simplex Perlin Noise 3D
         //  Return value range of 0 to 1
         //
         // derived from Brian Sharpes work at:
         // https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D.glsl
         //
         float Noise3D( float3 P )
         {
             //  https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D.glsl

             //  simplex math constants
             const float SKEWFACTOR = 1.0/3.0;
             const float UNSKEWFACTOR = 1.0/6.0;
             const float SIMPLEX_CORNER_POS = 0.5;
             const float SIMPLEX_TETRAHADRON_HEIGHT = 0.70710678118654752440084436210485;    // sqrt( 0.5 )

             //  establish our grid cell.
             P *= SIMPLEX_TETRAHADRON_HEIGHT;    // scale space so we can have an approx feature size of 1.0
             float3 Pi = floor( P + dot( P, float3( SKEWFACTOR, SKEWFACTOR, SKEWFACTOR) ) );

             //  Find the floattors to the corners of our simplex tetrahedron
             float3 x0 = P - Pi + dot(Pi, float3( UNSKEWFACTOR, UNSKEWFACTOR, UNSKEWFACTOR ) );
             float3 g = step(x0.yzx, x0.xyz);
             float3 l = 1.0 - g;
             float3 Pi_1 = min( g.xyz, l.zxy );
             float3 Pi_2 = max( g.xyz, l.zxy );
             float3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
             float3 x2 = x0 - Pi_2 + SKEWFACTOR;
             float3 x3 = x0 - SIMPLEX_CORNER_POS;

             //  pack them into a parallel-friendly arrangement
             float4 v1234_x = float4( x0.x, x1.x, x2.x, x3.x );
             float4 v1234_y = float4( x0.y, x1.y, x2.y, x3.y );
             float4 v1234_z = float4( x0.z, x1.z, x2.z, x3.z );

             // clamp the domain of our grid cell
             Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
             float3 Pi_inc1 = step( Pi, float3( (69.0 - 1.5).xxx ) ) * ( Pi + 1.0 );

             //   generate the random floattors
             float4 Pt = float4( Pi.xy, Pi_inc1.xy ) + float2( 50.0, 161.0 ).xyxy;
             Pt *= Pt;
             float4 V1xy_V2xy = lerp( Pt.xyxy, Pt.zwzw, float4( Pi_1.xy, Pi_2.xy ) );
             Pt = float4( Pt.x, V1xy_V2xy.xz, Pt.z ) * float4( Pt.y, V1xy_V2xy.yw, Pt.w );
             const float3 SOMELARGEFLOATS = float3( 635.298681, 682.357502, 668.926525 );
             const float3 ZINC = float3( 48.500388, 65.294118, 63.934599 );
             float3 lowz_mods =  float3(1, 1, 1) / ( SOMELARGEFLOATS.xyz + Pi.zzz * ZINC.xyz );
             float3 highz_mods = float3(1, 1, 1) / ( SOMELARGEFLOATS.xyz + Pi_inc1.zzz * ZINC.xyz );
             Pi_1 = ( Pi_1.z < 0.5 ) ? lowz_mods : highz_mods;
             Pi_2 = ( Pi_2.z < 0.5 ) ? lowz_mods : highz_mods;
             float4 hash_0 = frac( Pt * float4( lowz_mods.x, Pi_1.x, Pi_2.x, highz_mods.x ) ) - 0.49999;
             float4 hash_1 = frac( Pt * float4( lowz_mods.y, Pi_1.y, Pi_2.y, highz_mods.y ) ) - 0.49999;
             float4 hash_2 = frac( Pt * float4( lowz_mods.z, Pi_1.z, Pi_2.z, highz_mods.z ) ) - 0.49999;

             //   evaluate gradients
             float4 grad_results = rsqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 ) * ( hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z );

             //   Normalization factor to scale the final result to a strict 1.0->-1.0 range
             //   http://briansharpe.wordpress.com/2012/01/13/simplex-noise/#comment-36
             const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

             //  evaulate the kernel weights ( use (0.5-x*x)^3 instead of (0.6-x*x)^4 to fix discontinuities )
             float4 kernel_weights = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
             kernel_weights = max(0.5 - kernel_weights, 0.0);
             kernel_weights = kernel_weights*kernel_weights*kernel_weights;

             //   sum with the kernel and return
             return (dot( kernel_weights, grad_results ) * FINAL_NORMALIZATION) * 0.5 + 0.5;
         }

         float FBM3D(float3 x)
         {
            float f = 0;
            f += 0.5 * Noise3D(x); x *= 2.01;
            f += 0.25 * Noise3D(x); x * 2.02;
            f += 0.125 * Noise3D(x);
            return f * 1.14285714286;
         }

         // value in x, alpha in y
         float2 Band(float pnt, float center, float width, float blend, float minLimit, float maxLimit)
         {
             // x is actual band pass
             float x = lerp(minLimit, maxLimit, lerp(0.0, 1.0, 
                                                     smoothstep(saturate(center-width-blend), 
                                                                saturate(center-width), pnt)) *
                                                lerp(1.0, 0.0,
                                                     smoothstep(saturate(center+width),
                                                                saturate(center+width+blend), pnt)));
             
             
             // y is alpha
             float y = smoothstep(0.0, 1.0, saturate((pnt - center - width - blend) * (1.0/blend)));
             return float2(x,y);
         }

         // multi-band pass filtering, weight in x, texture in y
         float2 BandPass(float3 worldPos, float x, float t0, float t1, float4 range, float3 cwb)
         {
            float2 bp = Band(x, cwb.x, cwb.y, cwb.z, range.x, range.y);
            float rt = bp.y < 0.5 ? t0 : t1;
            bp.x = saturate(bp.x - FBM3D(worldPos * range.z) * range.w); 

            return float2(bp.x, rt);
         }

         float2 BandPass(float3 worldPos, float x, float t0, float t1, float t2, float4 range, float3 cwb, float4 range2, float3 cwb2)
         {
            float2 bp = Band(x, cwb.x, cwb.y, cwb.z, range.x, range.y);
            float2 bp2 = Band(x, cwb2.x, cwb2.y, cwb2.z, range2.x, range2.y);

            float rt = bp2.x > bp.x ? t1 : t0;
  
            bp.x = saturate(bp.x - FBM3D(worldPos * range.z) * range.w); 
            bp2.x = saturate(bp2.x - FBM3D(worldPos * range2.z) * range2.w); 

            float rf = lerp(bp.x, bp2.x, bp.y);
            rf = max(rf, bp2.x);
            return float2(rf, rt);
         }

         float2 BandPass(float3 worldPos, float x, float t0, float t1, float t2, float t3, 
                          float4 range, float3 cwb, float4 range2, float3 cwb2, float4 range3, float3 cwb3)
         {
            float2 bp = Band(x, cwb.x, cwb.y, cwb.z, range.x, range.y);
            float2 bp2 = Band(x, cwb2.x, cwb2.y, cwb2.z, range2.x, range2.y);
            float2 bp3 = Band(x, cwb3.x, cwb3.y, cwb3.z, range3.x, range3.y);

            float rt = t0;
            if (bp3.x > bp.x && bp3.x > bp2.x)
               rt = t2;
            else if (bp2.x > bp.x && bp2.x > bp3.x)
               rt = t1;


            bp.x = saturate(bp.x - FBM3D(worldPos * range.z) * range.w); 
            bp2.x = saturate(bp2.x - FBM3D(worldPos * range2.z) * range2.w); 
            bp3.x = saturate(bp3.x - FBM3D(worldPos * range3.z) * range3.w); 

            float rf = lerp(bp.x, bp2.x, bp.y);
            rf = max(rf, bp2.x);
            rf = lerp(rf, bp3.x, bp2.y);
            rf = max(rf, bp3.x);
            return float2(rf, rt);
         }

         float2 BandPass(float3 worldPos, float x, float t0, float t1, float t2, float t3, float t4,
                          float4 range, float3 cwb, 
                          float4 range2, float3 cwb2, 
                          float4 range3, float3 cwb3,
                          float4 range4, float3 cwb4)
         {
            float2 bp = Band(x, cwb.x, cwb.y, cwb.z, range.x, range.y);
            float2 bp2 = Band(x, cwb2.x, cwb2.y, cwb2.z, range2.x, range2.y);
            float2 bp3 = Band(x, cwb3.x, cwb3.y, cwb3.z, range3.x, range3.y);
            float2 bp4 = Band(x, cwb4.x, cwb4.y, cwb4.z, range4.x, range4.y);

            float rt = t0;
            if (bp4.x > bp.x && bp4.x > bp2.x && bp4.x > bp3.x)
               rt = t3;
            else if (bp3.x > bp.x && bp3.x > bp2.x && bp3.x > bp4.x)
               rt = t2;
            else if (bp2.x > bp.x && bp2.x > bp3.x && bp2.x > bp4.x)
               rt = t1;

            bp.x = saturate(bp.x - FBM3D(worldPos * range.z) * range.w); 
            bp2.x = saturate(bp2.x - FBM3D(worldPos * range2.z) * range2.w); 
            bp3.x = saturate(bp3.x - FBM3D(worldPos * range3.z) * range3.w); 
            bp4.x = saturate(bp4.x - FBM3D(worldPos * range4.z) * range4.w); 

            float rf = lerp(bp.x, bp2.x, bp.y);
            rf = max(rf, bp2.x);
            rf = lerp(rf, bp3.x, bp2.y);
            rf = max(rf, bp3.x);
            rf = lerp(rf, bp4.x, bp3.y);
            rf = max(rf, bp4.x);
            return float2(rf, rt);
         }



         float4 CustomProcedural(float3 localPos, float3 worldPos, float3 localNormal, 
                                 float3 worldNormal, float2 heights, float2 UV, float cavity)
         {
   if (_Pass < 1)
      return float4((float)0 / 255.0, (float)0 / 255.0, 1.0 - saturate(0), 1);
   else
      return float4(0, 0, 0, 1);

         }

			half4 frag (v2f i) : SV_Target
			{
				float3 localPosition = tex2D(_LocalPositions, i.uv).xyz;
            float3 worldPosition = tex2D(_WorldPositions, i.uv).xyz;
            float3 localNormal = tex2D(_LocalNormals, i.uv).xyz;
            float3 worldNormal = tex2D(_WorldNormals, i.uv).xyz;
            float3 UVcavity = tex2D(_UVCavity, i.uv).rgb;
            return CustomProcedural(localPosition, worldPosition, localNormal, worldNormal, _HeightBounds, UVcavity.xy, UVcavity.z);

			}
			ENDCG
		}
	}
}
