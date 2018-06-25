﻿using System.Collections.Generic;
using UnityEngine;

namespace Terra.Terrain.Detail {
	/// <summary>
	/// Class responsible for the displaying of details on a 
	/// Tile. These details include object placement, 
	/// material application, and 
	/// </summary>
	public class DetailManager {
		private Tile Tile;

		public TerrainPaint Paint { get; private set; }
		public static ObjectRenderer ObjectPlacer { get; private set; }
		
		public DetailManager(Tile tt) {
			Tile = tt;

			if (ObjectPlacer == null) {
				ObjectPlacer = new ObjectRenderer();
			}
		}

		/// <summary>
		/// Pushes frame update message to any details that change their visibility
		/// on a per-frame basis.
		/// </summary>
		public void Update() {
			GrassRenderer.Update();
		}

		/// <summary>
		/// Applies the SplatSettings specified in TerraSettings to this 
		/// Tile. A TerrainPaint instance is created if it didn't exist 
		/// already, and is returned.
		/// </summary>
		/// <returns>Tile instance</returns>
		public TerrainPaint ApplySplatmap() {
			TerraEvent.TriggerOnSplatmapWillCalculate(Tile.gameObject);
			if (Paint == null)
				Paint = new TerrainPaint(Tile.gameObject);

			List<Texture2D> maps = Paint.GenerateSplatmaps();
			maps.ForEach(m => TerraEvent.TriggerOnSplatmapDidCalculate(Tile.gameObject, m));

			return Paint;
		}
	}
}