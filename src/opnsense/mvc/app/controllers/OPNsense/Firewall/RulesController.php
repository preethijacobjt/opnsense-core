<?php

/*
 * Copyright (C) 2024 Deciso B.V.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
namespace OPNsense\Firewall;

use OPNsense\Core\Config;

class RulesController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/Firewall/rules');
        $this->view->ruleController = "rules";
        $this->view->tabs = self::getInterfaces();
        $this->view->default_tab = "floating";
        $this->view->gridFields = [
            [
                'id' => 'enabled', 'formatter' => 'rowtoggle', 'heading' => gettext('Enabled')
            ],
            [
                'id' => 'sequence', 'heading' => gettext('Sequence')
            ],
            [
                'id' => 'protocol', 'visible' => 'true', 'heading' => gettext('Protocol')
            ],
            [
                'id' => 'source_net', 'visible' => 'true', 'heading' => gettext('Source')
            ],
            [
                'id' => 'source_port', 'visible' => 'true', 'heading' => gettext('Port')
            ],
            [
                'id' => 'destination_net', 'visible' => 'true', 'heading' => gettext('Destination')
            ],
            [
                'id' => 'destination_port', 'visible' => 'true', 'heading' => gettext('Port')
            ],
            [
                'id' => 'gateway', 'visible' => 'true', 'heading' => gettext('Gateway')
            ],
            [
                'id' => 'schedule', 'visible' => 'true', 'heading' => gettext('Schedule')
            ],
            [
                'id' => 'evaluations', 'visible' => 'false', 'heading' => gettext('Evaluations')
            ],
            [
                'id' => 'states', 'visible' => 'false', 'heading' => gettext('States')
            ],
            [
                'id' => 'packets', 'visible' => 'false', 'heading' => gettext('Packets')
            ],
            [
                'id' => 'bytes', 'visible' => 'false', 'heading' => gettext('Bytes')
            ],
            [
                'id' => 'description', 'heading' => gettext('Description')
            ]
        ];

        $this->view->formDialogFilterRule = $this->getForm("dialogFirewallRule");
    }

    public function getInterfaces() {
        $interfaces['floating'] = [
                        "name" => "floating",
                        "caption" => "Floating"
                    ];
        if (Config::getInstance()->object()->interfaces->count() > 0) {
            foreach (Config::getInstance()->object()->interfaces->children() as $key => $node) {
                if (isset($node->enable)) {
                    $caption = !empty($node->descr) ? (string)$node->descr : strtoupper($key);
                    $interfaces[$key] = [
                        "name" => $key,
                        "caption" => gettext($caption)
                    ];
                }
            }
        }
        ksort($interfaces, SORT_NATURAL|SORT_FLAG_CASE);
        return $interfaces;
    }
}
