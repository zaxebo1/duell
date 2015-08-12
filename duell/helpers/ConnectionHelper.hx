/*
 * Copyright (c) 2003-2015, GameDuell GmbH
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

package duell.helpers;

import python.KwArgs;

import haxe.Http;

typedef URLOpenArgs =
{
    ?timeout: Int
}

@:pythonImport("urllib", "request")
extern class Request
{
    public static function urlopen(url: String, ?kwArgs: KwArgs<URLOpenArgs>): Void;
}


/**
    @author jxav
 */
class ConnectionHelper
{
    private static inline var TIMEOUT: Int = 3;

    private static var online: Bool = true;
    private static var initialized: Bool = false;

    public static function isOnline(): Bool
    {
        // only check once per tool run the connection state
        if (!initialized)
        {
            initialized = true;

            try {
                Request.urlopen("http://www.google.com", {timeout: 1});
            }
            catch (error: Dynamic) {
                LogHelper.println("");
                LogHelper.warn("Running duell tool in offline mode, this might cause undesired behaviors!");
                LogHelper.println("");
            }
        }

        return online;
    }
}
