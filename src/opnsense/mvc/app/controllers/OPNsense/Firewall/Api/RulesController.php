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

namespace OPNsense\Firewall\Api;

use OPNsense\Core\Backend;
use OPNsense\Firewall\Group;

class RulesController extends FilterBaseController
{
    protected static $categorysource = "firewallrules.rule";

    public function searchRuleAction()
    {
        $category = $this->request->get('category');
        $interface = $this->request->get('interface');
        $filter_funct = function ($record) use ($interface, $category) {
            $match_interface = empty($interface) || empty((string)$record->interface) || in_array($interface, explode(',', $record->interface)) || (count(explode(',', $record->interface))>1 && $interface=='floating');
            $match_category = empty($category) || array_intersect(explode(',', $record->categories), $category);
            return $match_interface && $match_category;
        };

        $rule_stats = json_decode((new Backend())->configdRun("filter rule stats") ?? '', true) ?? [];

        $otherrules = json_decode((new Backend())->configdRun("filter list non_mvc_rules") ?? '', true) ?? [];

        foreach ($otherrules as &$rule) {
            $uuid = $rule['uuid'];
            if (isset($rule_stats[$uuid])) {
                $rule += $rule_stats[$uuid];
            }
        }
        unset($rule);

        $filter_funct_rs  = function (&$record) use (
            $interface
        ) {
            if (count(explode(',', $record['interface']))>1 || (empty($record['interface']) && ($record['floating']==='yes' || $record['floating']==1))) {
                if ($interface!=='floating') {
                    $record['rule_type'] = 'floating';
                    if (empty($record['ref'])) {
                        $record['ref'] = 'ui/firewall/port_forward#'.$record['uuid'];
                    }
                } else {
                    $record['rule_type'] = '';
                }
            }
            
            $ifgroups = [];
            foreach ((new Group())->ifgroupentry->iterateItems() as $groupItem) {
                if (!empty((string)$groupItem->members) && in_array($interface, explode(',', (string)$groupItem->members))) {
                    $ifgroups[] = (string)$groupItem->ifname;
                }
            }

            if (isset($record['source']['network'])) {
                $record['source_net'] = $record['source']['network']." net";
            }
            if (isset($record['source']['any'])) {
                $record['source_net'] = "any";
            }
            if (isset($record['source']['address'])) {
                $record['source_net'] = $record['source']['address'];
            }
            if (isset($record['source']['port'])) {
                $record['source_port'] = $record['source']['port'];
            }
            if (isset($record['source']['not'])) {
                $record['source_not'] = $record['source']['not'];
            }
            if (isset($record['destination']['network'])) {
                $record['destination_net'] = $record['destination']['network']." net";
            }
            if (isset($record['destination']['any'])) {
                $record['destination_net'] = "any";
            }
            if (isset($record['destination']['address'])) {
                $record['destination_net'] = $record['destination']['address'];
            }
            if (isset($record['destination']['port'])) {
                $record['destination_port'] = $record['destination']['port'];
            }
            if (isset($record['destination']['not'])) {
                $record['destination_not'] = $record['destination']['not'];
            }
            if (isset($record['associated-rule-id'])) {
                $record['filter_rule'] = $record['associated-rule-id'];
                unset($record['associated-rule-id']);
            }

            $is_selected = false;
            if (empty($ifgroups) && $record['rule_type'] == 'group'){
                $is_selected = false;
            } elseif (strtolower($record['interface']) == $interface && empty($record['interface_invert'])) {
                $is_selected = true;
            } elseif ($interface == 'floating' && $record['rule_type'] == 'floating') {
                $is_selected = false;
            } elseif (!empty($record['interface_invert'])) {
                if (!in_array($interface, explode(',', strtolower(str_replace(", ", ",", $record['interface']))))) {
                    $is_selected = true;
                }
            } elseif (($record['interface'] == "" || strpos($record['interface'], ",") !== false) && $interface == 'floating') {
                $is_selected = true;
            } elseif ($record['interface'] == "" || !empty(array_intersect(array_merge([$interface], $ifgroups), explode(',', strtolower(str_replace(", ", ",", $record['interface'])))))) {
                $is_selected = true;
            }

            if ($record['enabled'] && $is_selected && $record['rule_type'] != 'interface') {
                return true;
            } elseif ($record['enabled'] && $is_selected && $record['rule_type'] == 'interface' && $record['interface'] == 'lan') {
                return true;
            } else {
                return false;
            }
        };
        $filterset = $this->searchBase("firewallrules.rule", null, "sequence", $filter_funct)['rows'];
        $rules = $this->searchBase("rules.rule", null, "sequence", $filter_funct)['rows'];
        if(!empty($rules)) {
            foreach ($rules as &$value) {
                $value['rule_type'] = 'automation';
                $value['ref'] = 'ui/firewall/filter#'.$value['uuid'];
            }
        }
        return $this->searchRecordsetBase(array_merge($otherrules, $filterset, $rules), null, "sequence", $filter_funct_rs);
    }

    public function setRuleAction($uuid)
    {
        return $this->setBase("rule", "firewallrules.rule", $uuid);
    }

    public function addRuleAction()
    {
        $floating = 0;
        if(count(explode(",", $this->request->get('rule')['interface'])) > 1 || empty($this->request->get('rule')['interface'])) {
            $floating = 1;
        }
        $overlay = [
            'floating' => $floating
        ];
        return $this->addBase("rule", "firewallrules.rule", $overlay);
    }

    public function getRuleAction($uuid = null)
    {
        return $this->getBase("rule", "firewallrules.rule", $uuid);
    }

    public function delRuleAction($uuid)
    {
        return $this->delBase("firewallrules.rule", $uuid);
    }

    public function toggleRuleAction($uuid, $enabled = null)
    {
        return $this->toggleBase("firewallrules.rule", $uuid, $enabled);
    }
}
