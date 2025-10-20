/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger.CollectionUtils {
    /**
     * Converts a Gee.ArrayList to a native Vala array
     * Eliminates code duplication across the codebase
     *
     * @param list The ArrayList to convert
     * @return Native array of strings
     */
    public string[] arraylist_to_array (Gee.ArrayList<string> list) {
        string[] array = new string[list.size];
        for (int i = 0; i < list.size; i++) {
            array[i] = list[i];
        }
        return array;
    }

    /**
     * Safely joins array elements with a separator
     *
     * @param array The array to join
     * @param separator The separator string
     * @return Joined string
     */
    public string safe_join (string[] array, string separator) {
        if (array.length == 0) {
            return "";
        }
        return string.joinv (separator, array);
    }
}
